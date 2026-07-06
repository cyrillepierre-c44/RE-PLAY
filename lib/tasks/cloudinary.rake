namespace :cloudinary do
  desc "Retraite les photos de jouets déjà stockées via la transformation d'upload (config/storage.yml) et purge les anciens fichiers"
  task recompress_photos: :environment do
    unless ActiveStorage::Blob.service.class.name == "ActiveStorage::Service::CloudinaryService"
      abort "Le service Active Storage courant (RAILS_ENV=#{Rails.env}) n'est pas Cloudinary. Abandon."
    end

    dry_run = ActiveModel::Type::Boolean.new.cast(ENV.fetch("DRY_RUN", nil))
    limit = ENV.fetch("LIMIT", nil)&.to_i

    toys = Toy.joins(:photo_attachment)
    toys = toys.limit(limit) if limit
    total = toys.count

    puts "#{total} jouet(s) avec photo à retraiter#{' (DRY_RUN, aucune modification)' if dry_run}."

    processed = 0
    failed = 0

    toys.find_each do |toy|
      old_blob = toy.photo.blob
      # byte_size ici correspond au fichier tel qu'envoyé, pas à sa taille
      # après transformation côté Cloudinary (seul le dashboard Cloudinary
      # reflète la taille réellement stockée).
      before_bytes = old_blob.byte_size

      if dry_run
        puts "[dry-run] Toy##{toy.id}: #{old_blob.filename} (#{before_bytes} octets envoyés à l'origine)"
        next
      end

      begin
        old_blob.open do |file|
          toy.photo.attach(
            io: file,
            filename: old_blob.filename.to_s,
            content_type: old_blob.content_type
          )
        end
        old_blob.purge

        processed += 1
        puts "[#{processed}/#{total}] Toy##{toy.id}: retraité et ancien fichier purgé."
      rescue StandardError => e
        failed += 1
        warn "Toy##{toy.id}: échec (#{e.class}: #{e.message})"
      end
    end

    puts "Terminé. #{processed} retraité(s), #{failed} échec(s)." unless dry_run
  end
end
