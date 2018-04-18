class CreateCryptCiphers < ActiveRecord::Migration[5.1]
  def change
    create_table :crypt_ciphers do |t|
      t.string :key
      t.string :iv
      t.string :tag
      t.references :user, foreign_key: true

      t.timestamps
    end
  end
end
