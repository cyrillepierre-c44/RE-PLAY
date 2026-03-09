class CreateActions < ActiveRecord::Migration[8.1]
  def change
    create_table :actions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :content
      t.belongs_to :actionable, polymorphic: true

      t.timestamps
    end
  end
end
