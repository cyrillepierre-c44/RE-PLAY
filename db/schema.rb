# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_03_09_145343) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "actions", force: :cascade do |t|
    t.bigint "actionable_id"
    t.string "actionable_type"
    t.string "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["actionable_type", "actionable_id"], name: "index_actions_on_actionable"
    t.index ["user_id"], name: "index_actions_on_user_id"
  end

  create_table "boxes", force: :cascade do |t|
      t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.boolean "electronic"
    t.datetime "updated_at", null: false
    t.decimal "weight"
    t.index ["category_id"], name: "index_boxes_on_category_id"
  end

  create_table "categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "toys", force: :cascade do |t|
    t.string "barcode"
    t.bigint "box_id", null: false
    t.bigint "category_id", null: false
    t.boolean "clean"
    t.boolean "complete"
    t.datetime "created_at", null: false
    t.boolean "playable"
    t.decimal "price"
    t.datetime "updated_at", null: false
    t.index ["box_id"], name: "index_toys_on_box_id"
    t.index ["category_id"], name: "index_toys_on_category_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "actions", "users"
  add_foreign_key "boxes", "categories"
  add_foreign_key "toys", "boxes"
  add_foreign_key "toys", "categories"
end
