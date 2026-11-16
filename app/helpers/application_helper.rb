module ApplicationHelper
  # Bandeau d'un jouet refusé au contrôle qualité : orange tant que le délai est
  # tenu, rouge au-delà de `red_after_days` jours ouvrés (réglage des admins).
  def cq_banner(toy)
    check = toy.open_check
    days = check&.working_days_open
    @cq_red_after ||= QualitySetting.current.red_after_days
    late = check.present? && toy.review? && days > @cq_red_after
    label = toy.arbitrage? ? "À arbitrer" : "CQ refusé"
    since = if days.nil?
              nil
            else
              (days.zero? ? "aujourd'hui" : "#{days} j")
            end
    icon = toy.arbitrage? ? "fa-scale-balanced" : "fa-triangle-exclamation"
    content_tag(:div, class: "toy-card-review-badge #{'toy-card-review-badge--late' if late}") do
      safe_join([tag.i(class: "fa-solid #{icon}", aria: { hidden: true }), " ",
                 [label, since, ("en retard" if late)].compact.join(" · ")])
    end
  end

  # Un jouet peut ne pas (encore) avoir de catégorie : créé depuis une caisse
  # « Grosses pièces », il n'hérite pas de celle de la caisse et attend le choix
  # de l'opérateur. Les badges affichent alors un point d'interrogation.
  def category_icon(category)
    return "fa-circle-question" unless category

    category.icon.presence || "fa-tag"
  end

  def category_name(category)
    category&.name || "À choisir"
  end

  # Double gift icon representing a collection of toys (jouets).
  # Use single fa-gift for a specific toy, this helper for lists/counts.
  def toys_icon(html_class: nil, style: nil)
    span_style = "display:inline-block;position:relative;width:1.2em;height:1.1em;vertical-align:middle;"
    span_style += style if style
    content_tag(:span, style: span_style, class: html_class) do
      tag.i(class: "fa-solid fa-gift", aria: { hidden: true },
            style: "position:absolute;font-size:0.7em;top:0;left:0;") +
        tag.i(class: "fa-solid fa-gift", aria: { hidden: true },
              style: "position:absolute;font-size:0.7em;bottom:0;right:0;")
    end
  end

  # Vignette des cartes jouet (listes) : la carte fait 200 px de haut, inutile d'envoyer la
  # photo de 1600 px. On demande à Cloudinary une image recadrée à la taille de la carte
  # (720×400, nette sur un écran haute densité), en WebP/AVIF quand le téléphone le
  # supporte : ~4× moins de bande passante. Hors Cloudinary (dev, tests) : photo d'origine.
  TOY_THUMB_TRANSFORMATION = { width: 720, height: 400, crop: :fill, gravity: :center,
                               quality: :auto, fetch_format: :auto }.freeze

  def toy_thumb_tag(toy)
    blob = toy.photo.blob
    src = if defined?(ActiveStorage::Service::CloudinaryService) && blob.service.is_a?(ActiveStorage::Service::CloudinaryService)
            blob.service.url(blob.key, filename: blob.filename, content_type: blob.content_type,
                                       transformation: TOY_THUMB_TRANSFORMATION.dup)
          else
            toy.photo
          end
    # lazy : seules les cartes visibles à l'écran sont téléchargées
    image_tag src, alt: "Photo du jouet J#{toy.id}", class: "toy-card-img", loading: "lazy", decoding: "async"
  end
end
