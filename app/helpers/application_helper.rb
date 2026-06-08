module ApplicationHelper
  # Double gift icon representing a collection of toys (jouets).
  # Use single fa-gift for a specific toy, this helper for lists/counts.
  def toys_icon(html_class: nil, style: nil)
    span_style = "display:inline-block;position:relative;width:1.2em;height:1.1em;vertical-align:middle;"
    span_style += style if style
    content_tag(:span, style: span_style, class: html_class) do
      tag.i(class: "fa-solid fa-gift",
            style: "position:absolute;font-size:0.7em;top:0;left:0;") +
      tag.i(class: "fa-solid fa-gift",
            style: "position:absolute;font-size:0.7em;bottom:0;right:0;")
    end
  end
end
