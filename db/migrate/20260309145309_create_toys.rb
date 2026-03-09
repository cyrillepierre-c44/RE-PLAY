class CreateToys < ActiveRecord::Migration[8.1]
  def change
    create_table :toys do |t|
      t.decimal :price
      t.string :barcode
      t.boolean :complete
      t.boolean :clean
      t.boolean :playable
      t.references :box, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true

      t.timestamps
    end
  end
end
