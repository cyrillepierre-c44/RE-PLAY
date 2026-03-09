class CreateBoxes < ActiveRecord::Migration[8.1]
  def change
    create_table :boxes do |t|
      t.references :category, null: false, foreign_key: true
      t.decimal :weight
      t.boolean :electronic

      t.timestamps
    end
  end
end
