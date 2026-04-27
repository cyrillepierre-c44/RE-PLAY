class AddAdminCommentToToys < ActiveRecord::Migration[8.1]
  def change
    add_column :toys, :admin_comment, :string, limit: 255
  end
end
