namespace :cloudinary do
  desc "Retraite les photos de jouets déjà stockées via la transformation d'upload (config/storage.yml) et purge les anciens fichiers"
  task recompress_photos: :environment do
    dry_run = ActiveModel::Type::Boolean.new.cast(ENV.fetch("DRY_RUN", nil))
    limit = ENV.fetch("LIMIT", nil)&.to_i

    # Filtre par service du blob (pas par service par défaut de l'environnement) :
    # ça permet de tester la tâche en dev sur les quelques photos qui y ont été
    # uploadées vers Cloudinary avant la séparation dev/prod, sans toucher aux
    # vraies photos de prod (dossier "development" isolé sur le même compte).
    toys = Toy.joins(photo_attachment: :blob).where(active_storage_blobs: { service_name: "cloudinary" })
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
        # `blob.download` (et non `blob.open`) : Cloudinary sert déjà l'ancien
        # fichier via l'URL transformée (redimensionnée), donc les octets
        # livrés ne correspondent plus au checksum calculé à l'upload d'origine.
        # `open` vérifie ce checksum et lèverait IntegrityError ; `download`
        # renvoie les octets bruts sans vérification.
        StringIO.open(old_blob.download) do |io|
          toy.photo.attach(
            io: io,
            filename: old_blob.filename.to_s,
            content_type: old_blob.content_type,
            service_name: old_blob.service_name
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

  desc "Purge les blobs Cloudinary orphelins (jouets supprimés dont la photo n'a jamais été nettoyée)"
  task purge_orphaned_blobs: :environment do
    dry_run = ActiveModel::Type::Boolean.new.cast(ENV.fetch("DRY_RUN", nil))
    limit = ENV.fetch("LIMIT", nil)&.to_i

    blobs = ActiveStorage::Blob.left_joins(:attachments)
                               .where(active_storage_attachments: { id: nil })
                               .where(service_name: "cloudinary")
    blobs = blobs.limit(limit) if limit
    total = blobs.count

    puts "#{total} blob(s) orphelin(s) sur Cloudinary#{' (DRY_RUN, aucune modification)' if dry_run}."

    purged = 0
    failed = 0

    blobs.find_each do |blob|
      if dry_run
        puts "[dry-run] Blob##{blob.id}: #{blob.filename} (#{blob.byte_size} octets)"
        next
      end

      begin
        blob.purge
        purged += 1
        puts "[#{purged}/#{total}] Blob##{blob.id} (#{blob.filename}) purgé."
      rescue StandardError => e
        failed += 1
        warn "Blob##{blob.id}: échec (#{e.class}: #{e.message})"
      end
    end

    puts "Terminé. #{purged} purgé(s), #{failed} échec(s)." unless dry_run
  end
end
