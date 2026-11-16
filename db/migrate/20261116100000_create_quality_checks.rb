# Suivi qualité (lot 1) :
# - quality_checks : une ligne par décision du contrôle qualité (CQ) sur un jouet.
#   Tour 1 et tour 2 (après revalorisation), puis au besoin l'arbitrage (round 3).
#   Un contrôle refusé EST une non-conformité : ouverte tant que `reworked_at`
#   est vide, close pour de bon quand `resolved_at` est rempli.
# - toys.operator_id : le valorisateur (créateur de la fiche), à qui la
#   non-conformité est comptée ; toys.assignee_id : la personne à qui un admin a
#   confié le jouet (opérateur absent) ; toys.discard_causes : causes du jet à
#   l'entrée de la VALO (mesure la qualité du TRI).
# - quality_settings : objectifs réglables par les admins (ligne unique).
class CreateQualityChecks < ActiveRecord::Migration[8.1]
  def up
    create_table :quality_checks do |t|
      t.references :toy, null: false, foreign_key: true
      t.integer :round, null: false
      t.string :decision, null: false
      t.string :causes, array: true, null: false, default: []
      t.text :cq_comment
      t.text :operator_comment
      t.references :operator, foreign_key: { to_table: :users, on_delete: :nullify }
      t.references :checker, foreign_key: { to_table: :users, on_delete: :nullify }
      t.datetime :reworked_at
      t.datetime :resolved_at
      t.timestamps
    end
    add_index :quality_checks, %i[decision reworked_at]
    add_index :quality_checks, :created_at

    add_reference :toys, :operator, foreign_key: { to_table: :users, on_delete: :nullify }
    add_reference :toys, :assignee, foreign_key: { to_table: :users, on_delete: :nullify }
    add_column :toys, :discard_causes, :string, array: true, null: false, default: []

    create_table :quality_settings do |t|
      t.integer :target_valo, null: false, default: 90
      t.integer :target_tri, null: false, default: 95
      t.integer :red_after_days, null: false, default: 3
      t.timestamps
    end

    # Valorisateur des jouets existants : l'auteur de leur première action
    # (même définition que le « créateur » de l'ancien tableau de bord).
    execute <<~SQL.squish
      UPDATE toys SET operator_id = first_action.user_id
      FROM (
        SELECT DISTINCT ON (actionable_id) actionable_id, user_id
        FROM actions WHERE actionable_type = 'Toy'
        ORDER BY actionable_id, created_at ASC, id ASC
      ) AS first_action
      WHERE first_action.actionable_id = toys.id
    SQL
  end

  def down
    drop_table :quality_settings
    remove_column :toys, :discard_causes
    remove_reference :toys, :assignee, foreign_key: { to_table: :users }
    remove_reference :toys, :operator, foreign_key: { to_table: :users }
    drop_table :quality_checks
  end
end
