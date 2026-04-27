class AddOperatorNoteToToys < ActiveRecord::Migration[8.1]
  def change
    add_column :toys, :operator_note, :text
  end
end
