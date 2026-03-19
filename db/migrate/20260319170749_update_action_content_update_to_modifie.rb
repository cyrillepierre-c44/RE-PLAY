class UpdateActionContentUpdateToModifie < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE actions SET content = REPLACE(content, 'a updaté', 'a modifié') WHERE content LIKE '%a updaté%'"
  end

  def down
    execute "UPDATE actions SET content = REPLACE(content, 'a modifié', 'a updaté') WHERE content LIKE '%a modifié%'"
  end
end
