# Chiffres du volet qualité du tableau de bord (page /dashboard), pour une
# période donnée. Définitions arrêtées avec Enjoué le 16/11/2026 :
#
# - Bon du 1er coup VALO = jouets mis en vente dès le 1er contrôle ÷ jouets
#   passés au 1er contrôle sur la période (les envois directs au vrac, au don ou
#   au rebut ne sont comptés ni en bon ni en non conforme).
# - Bon du 1er coup TRI = jouets sortis des caisses qui n'ont PAS été jetés à
#   l'entrée pour une cause que le TRI devait écarter (QualityCause::TRI_KEYS)
#   ÷ jouets sortis des caisses. Le TRI d'une caisse = la personne qui l'a créée.
# - Un jouet est rangé dans la période où il a été CONTRÔLÉ, pas valorisé : sur une
#   journée, le taux d'un opérateur ne dit rien de son travail du jour, et un
#   échantillon de 10 jouets bascule de 10 points à chaque refus. D'où le seuil
#   `min_sample` (réglable) sous lequel aucun pourcentage n'est affiché, et la
#   vue du jour (`daily?`) qui suit le stock : NC ouvertes, reçues, retraitées.
# - Délais en jours ouvrés (WorkingDays).
# - « En ce moment » ne dépend pas de la période : c'est l'état de l'atelier.
class QualityDashboard
  TOP_CAUSES = 5
  WEEKS = 8

  attr_reader :range, :setting

  def initialize(range)
    @range = range
    @setting = QualitySetting.current
  end

  # Assez de jouets pour qu'un pourcentage ait un sens ?
  def reliable?(total) = total.to_i >= setting.min_sample

  # Période d'une journée (Aujourd'hui, Hier, ou deux dates identiques).
  def daily? = (range.end - range.begin) <= 1.day

  # ── En ce moment ────────────────────────────────────────────────────────
  def open_checks
    # Même définition que la liste « À reprendre » : le dernier refus de chaque jouet « CQ refusé ».
    @open_checks ||= Toy.review.includes(:quality_checks).filter_map(&:open_check).sort_by(&:created_at)
  end

  def late_checks = open_checks.select { |check| check.late?(setting.red_after_days) }
  def oldest_open_days = open_checks.first&.working_days_open
  def arbitrage_count = Toy.arbitrage.count

  # ── VALO ────────────────────────────────────────────────────────────────
  def first_round = @first_round ||= QualityCheck.rated.where(round: 1, created_at: range).to_a
  def refusals = @refusals ||= QualityCheck.refused.where(created_at: range).to_a
  def valo_total = first_round.size
  def valo_ok = first_round.count(&:accepted?)
  def fpy_valo = rate(valo_ok, valo_total)
  def nc_rate = fpy_valo && (100 - fpy_valo)
  def problems_count = refusals.sum { |check| causes_of(check).size }

  # Causes d'un refus ; un refus sans cause (historique) vaut un problème « non renseigné ».
  def causes_of(check) = check.causes.presence || [QualityCause::UNKNOWN.key]

  def second_round = @second_round ||= QualityCheck.rated.where(round: 2, created_at: range).to_a
  def second_refusal_rate = rate(second_round.count(&:refused?), second_round.size)

  def rework_delay = average_days(refusals.select(&:reworked_at)) { |c| WorkingDays.elapsed(c.created_at, c.reworked_at) }
  def total_delay = average_days(refusals.select(&:resolved_at)) { |c| WorkingDays.elapsed(c.created_at, c.resolved_at) }

  # [{ cause:, count:, share: (largeur de barre), cumulative:, delay: }] du plus fréquent au plus rare
  def cause_rows
    @cause_rows ||= begin
      counts = refusals.flat_map { |check| causes_of(check) }.tally
      max = counts.values.max.to_f
      running = 0
      all_causes = QualityCause::CQ + [QualityCause::UNKNOWN]
      all_causes.select { |cause| counts[cause.key] }.sort_by { |cause| -counts[cause.key] }.map do |cause|
        running += counts[cause.key]
        reworked = refusals.select { |c| c.reworked_at && causes_of(c).include?(cause.key) }
        { cause: cause, count: counts[cause.key], share: (counts[cause.key] / max * 100).round,
          cumulative: rate(running, problems_count),
          delay: average_days(reworked) { |c| WorkingDays.elapsed(c.created_at, c.reworked_at) } }
      end
    end
  end

  # Bon du 1er coup des WEEKS dernières semaines COMPLÈTES (jusqu'à la fin de la
  # période). La semaine en cours n'y figure pas : son taux bouge d'heure en heure
  # en début de semaine, il ne se compare aux autres qu'une fois la semaine finie.
  def weekly
    @weekly ||= begin
      reference = [range.end, Time.current].min
      last_monday = reference.to_date.beginning_of_week(:monday)
      last_monday -= 1.week if (last_monday + 6).end_of_day > Time.current
      first_monday = last_monday - (WEEKS - 1).weeks
      checks = QualityCheck.rated.where(round: 1, created_at: first_monday.beginning_of_day..(last_monday + 6).end_of_day)
                           .pluck(:created_at, :decision)
      by_week = checks.group_by { |created_at, _| created_at.to_date.beginning_of_week(:monday) }
      (0...WEEKS).map do |i|
        monday = first_monday + i.weeks
        rows = by_week[monday] || []
        { monday: monday, label: "S#{monday.cweek}", total: rows.size,
          fpy: (rate(rows.count { |_, decision| decision == "accepted" }, rows.size) if reliable?(rows.size)) }
      end
    end
  end

  # Une ligne par valorisateur, du meilleur Bon du 1er coup au moins bon.
  def operator_rows
    @operator_rows ||= begin
      reworked = QualityCheck.refused.where(reworked_at: range).group(:operator_id).count
      ids = (first_round.map(&:operator_id) + refusals.map(&:operator_id) + open_checks.map(&:operator_id) + reworked.keys).uniq
      users = User.where(id: ids.compact).index_by(&:id)
      rows = ids.map do |id|
        firsts = first_round.select { |c| c.operator_id == id }
        mine = refusals.select { |c| c.operator_id == id }
        opened = open_checks.select { |c| c.operator_id == id }
        { user: users[id], id: id, total: firsts.size, ok: firsts.count(&:accepted?),
          fpy: rate(firsts.count(&:accepted?), firsts.size), refused: mine.size,
          problems: mine.sum { |c| causes_of(c).size }, causes: mine.flat_map { |c| causes_of(c) }.tally,
          delay: average_days(mine.select(&:reworked_at)) { |c| WorkingDays.elapsed(c.created_at, c.reworked_at) },
          open: opened.size, late: opened.count { |c| c.late?(setting.red_after_days) },
          reworked: reworked[id].to_i, reliable: reliable?(firsts.size) }
      end
      # Vue du jour : ceux qui ont le plus de retard d'abord. Sinon : les taux fiables, du meilleur au moins bon.
      if daily?
        rows.sort_by { |row| [-row[:late], -row[:open], -row[:refused]] }
      else
        rows.sort_by { |row| [row[:reliable] ? 0 : 1, -(row[:fpy] || -1), -row[:total]] }
      end
    end
  end

  def matrix_causes = cause_rows.first(TOP_CAUSES).map { |row| row[:cause] }
  def matrix_max = operator_rows.flat_map { |row| row[:causes].values }.max.to_i

  # ── TRI ─────────────────────────────────────────────────────────────────
  def toys_out
    @toys_out ||= Toy.not_draft.where(created_at: range).pluck(:id, :box_id, :status, :discard_causes)
                     .map { |id, box_id, status, causes| { id: id, box_id: box_id, status: status, causes: causes } }
  end

  def tri_rejects = toys_out.select { |toy| toy[:causes].intersect?(QualityCause::TRI_KEYS) }
  def valo_rejects = toys_out.select { |toy| toy[:causes].any? && !toy[:causes].intersect?(QualityCause::TRI_KEYS) }
  def fpy_tri = rate(toys_out.size - tri_rejects.size, toys_out.size)

  def discard_rows
    @discard_rows ||= begin
      counts = toys_out.flat_map { |toy| toy[:causes] }.tally
      max = counts.values.max.to_f
      QualityCause::DISCARD.select { |cause| counts[cause.key] }.sort_by { |cause| -counts[cause.key] }.map do |cause|
        { cause: cause, count: counts[cause.key], share: (counts[cause.key] / max * 100).round }
      end
    end
  end

  # Une ligne par responsable de caisse (créateur = auteur de la 1re action sur la caisse).
  def sorter_rows
    @sorter_rows ||= begin
      creators = box_creators(toys_out.map { |toy| toy[:box_id] }.uniq)
      users = User.where(id: creators.values.uniq).index_by(&:id)
      rows = toys_out.group_by { |toy| creators[toy[:box_id]] }.map do |user_id, toys|
        rejected = toys.count { |toy| toy[:causes].intersect?(QualityCause::TRI_KEYS) }
        { user: users[user_id], id: user_id, total: toys.size, rejected: rejected, fpy: rate(toys.size - rejected, toys.size),
          reliable: reliable?(toys.size) }
      end
      rows.sort_by { |row| [row[:reliable] ? 0 : 1, -(row[:fpy] || -1), -row[:total]] }
    end
  end

  # ── Détail (clic sur une barre, un point, une case…) ─────────────────────
  # Renvoie [titre, contrôles] ou, pour le TRI, [titre, jouets].
  def detail(filter)
    case filter[:scope]
    when "open" then ["Non-conformités ouvertes", with_people(open_checks)]
    when "late" then ["Non-conformités en retard (rouge)", with_people(late_checks)]
    when "tri" then tri_detail(filter)
    else valo_detail(filter)
    end
  end

  def box_creators(box_ids)
    Action.where(actionable_type: "Box", actionable_id: box_ids)
          .select("DISTINCT ON (actionable_id) actionable_id, user_id")
          .order("actionable_id, created_at ASC, id ASC").to_h { |a| [a.actionable_id, a.user_id] }
  end

  private

  def valo_detail(filter)
    checks = QualityCheck.refused.where(created_at: range).includes(toy: %i[operator assignee quality_checks])
    titles = []
    if filter[:cause].to_s == QualityCause::UNKNOWN.key
      checks = checks.where(causes: [])
      titles << QualityCause::UNKNOWN.label
    elsif (cause = QualityCause.cq(filter[:cause].to_s))
      checks = checks.where("? = ANY(causes)", cause.key)
      titles << cause.label
    end
    if filter[:operator_id].present?
      checks = checks.where(operator_id: filter[:operator_id])
      titles << short_name(filter[:operator_id])
    end
    if (monday = parse_date(filter[:week]))
      checks = QualityCheck.refused.where(round: 1, created_at: monday.beginning_of_day..(monday + 6).end_of_day)
                           .includes(toy: %i[operator assignee quality_checks])
      titles = ["Refus de la semaine #{monday.cweek}"]
    end
    [titles.presence&.join(" · ") || "Tous les refus de la période", checks.order(created_at: :desc).limit(200).to_a]
  end

  def tri_detail(filter)
    toys = Toy.where(created_at: range).where.not(discard_causes: []).includes(:operator, :box)
    title = "Jouets écartés à l'entrée de la VALO"
    if (cause = QualityCause.discard(filter[:cause].to_s))
      toys = toys.where("? = ANY(discard_causes)", cause.key)
      title = "Jetés à l'entrée · #{cause.label}"
    end
    list = toys.order(created_at: :desc).limit(200).to_a
    if filter[:sorter_id].present?
      creators = box_creators(list.map(&:box_id).uniq)
      list = list.select { |toy| creators[toy.box_id].to_s == filter[:sorter_id].to_s && toy.discard_causes.intersect?(QualityCause::TRI_KEYS) }
      title = "Jetés à l'entrée · caisses de #{short_name(filter[:sorter_id])}"
    end
    [title, list]
  end

  # Le panneau de détail affiche l'opérateur de chaque jouet : chargés en une fois.
  def with_people(checks)
    ActiveRecord::Associations::Preloader.new(records: checks.map(&:toy), associations: %i[operator assignee]).call
    checks
  end

  def short_name(user_id)
    User.find_by(id: user_id)&.email.to_s.split("@").first || "?"
  end

  def parse_date(value)
    Date.iso8601(value.to_s)
  rescue ArgumentError
    nil
  end

  def rate(part, total) = total.to_i.zero? ? nil : (part * 100.0 / total).round

  def average_days(records, &)
    return nil if records.empty?

    (records.sum(&) / records.size.to_f).round(1)
  end
end
