class AddFileNameToCryptCipher < ActiveRecord::Migration[5.1]
  def change
    add_column :crypt_ciphers, :filename, :string
  end
end
