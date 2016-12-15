# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20161215011207) do

  create_table "hosts", force: true do |t|
    t.string   "ip"
    t.string   "mac"
    t.string   "vendor"
    t.string   "os"
    t.string   "os_cpe"
    t.string   "name"
    t.string   "description"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "hosts", ["mac"], name: "index_hosts_on_mac", unique: true

  create_table "issues", force: true do |t|
    t.string   "host_id"
    t.boolean  "accepted", :default=>false
    t.string   "reason"
    t.text     "description"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "issues", ["accepted"], name: "index_issues_on_accepted"

  create_table "ports", force: true do |t|
    t.integer  "host_id"
    t.integer  "port"
    t.string   "proto"
    t.string   "name"
    t.text     "description"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "product"
    t.string   "version"
    t.string   "cpe"
  end

  add_index "ports", ["host_id", "port", "proto"], name: "index_ports_on_host_id_and_port_and_proto", unique: true

end
