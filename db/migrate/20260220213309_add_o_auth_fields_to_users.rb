class AddOAuthFieldsToUsers < ActiveRecord::Migration[8.2]
  def change
    add_column :users, :provider, :string
    add_column :users, :uid, :string
    add_column :users, :avatar_url, :string

    # Make password_digest nullable for SSO users
    change_column_null :users, :password_digest, true

    add_index :users, [:provider, :uid], unique: true, where: "provider IS NOT NULL"
  end
end
