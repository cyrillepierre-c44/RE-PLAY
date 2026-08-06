class DropPgSearchDocuments < ActiveRecord::Migration[8.1]
  # Table résiduelle : la gem pg_search a été retirée du Gemfile mais sa
  # table est restée en base.
  def up
    drop_table :pg_search_documents, if_exists: true
  end

  def down
    create_table :pg_search_documents do |t|
      t.text :content
      t.belongs_to :searchable, polymorphic: true, index: true
      t.timestamps
    end
  end
end
