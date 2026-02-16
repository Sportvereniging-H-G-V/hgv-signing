# frozen_string_literal: true

class DropDatabaseBackupTables < ActiveRecord::Migration[7.1]
  def up
    drop_table :database_exports, if_exists: true
    drop_table :database_imports, if_exists: true
  end

  def down
    create_table :database_exports do |t|
      t.references :account, null: false, foreign_key: true
      t.string :status, default: 'pending'
      t.string :error_message
      t.string :file_path
      t.bigint :file_size
      t.timestamps
    end

    create_table :database_imports do |t|
      t.references :account, null: false, foreign_key: true
      t.string :status, default: 'pending'
      t.string :error_message
      t.string :backup_path
      t.json :metadata
      t.timestamps
    end
  end
end
