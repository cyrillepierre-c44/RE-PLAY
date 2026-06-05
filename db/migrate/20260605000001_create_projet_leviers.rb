class CreateProjetLeviers < ActiveRecord::Migration[8.1]
  def change
    create_table :projet_leviers do |t|
      t.string  :module_code, null: false
      t.integer :numero, null: false
      t.boolean :actif, null: false, default: true
      t.integer :progression, null: false, default: 0

      t.timestamps
    end

    add_index :projet_leviers, [:module_code, :numero], unique: true
  end
end
