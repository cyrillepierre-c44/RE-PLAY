module DashboardPareto
  private

  def build_pareto_stats
    weight_by_cat, price_by_cat = pareto_category_metrics
    @pareto_data = pareto_rows(weight_by_cat, price_by_cat)
    add_pareto_cumulative
    vital = @pareto_data.select { |r| r[:cumulative] <= 80 }
    @pareto_data = vital.presence || @pareto_data.first(1)
  end

  def pareto_category_metrics
    [
      Box.where(id: @box_ids).group(:category_id).sum(:weight),
      Toy.where(id: @toy_ids).group(:category_id).sum(:price)
    ]
  end

  def pareto_rows(weight_by_cat, price_by_cat)
    @pareto_total_weight = weight_by_cat.values.sum.to_f
    @pareto_total_price  = price_by_cat.values.sum.to_f
    cat_ids = (weight_by_cat.keys + price_by_cat.keys).uniq.compact
    cats    = Category.where(id: cat_ids).index_by(&:id)
    cat_ids.map { |id| pareto_row(id, cats, weight_by_cat, price_by_cat) }
           .sort_by { |r| -r[:score] }
  end

  def pareto_row(id, cats, weight_by_cat, price_by_cat)
    weight = weight_by_cat[id].to_f
    price  = price_by_cat[id].to_f
    norm_p = @pareto_total_price.positive? ? price / @pareto_total_price : 0
    { category: cats[id], weight: weight, price: price, score: norm_p }
  end

  def add_pareto_cumulative
    total = @pareto_data.sum { |r| r[:score] }
    cumul = 0.0
    @pareto_data.each do |row|
      cumul += total.positive? ? row[:score] / total * 100 : 0
      row[:cumulative] = cumul.round(1)
    end
  end
end
