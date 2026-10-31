module ApplicationHelper
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
