class FilesUploadController < ApplicationController
  after_action :clear_when_five_minute_pass, only: :create
  require 'openssl'
  require 'base64'
  require 'fileutils'
  def new; end

  def index
    @files = CryptCipher.all
  end

  def create
    enc_or_dec = params[:request][:crypt]
    directory_name = Time.now.to_i.to_s(:number)
    Dir.mkdir(Rails.root.join('public', 'delete', directory_name).to_s)
    files_array = session[:files].split(', ')
    files_array.each do |file|
      if enc_or_dec == 'true'
        encrypt_uploaded_file(file, params[:request][:cipher_value], logged_in?)
      else
        decrypt_uploaded_file(file, params[:request][:cipher_value], logged_in?)
      end
    end
    if files_array.length > 1
      @zip_name = Time.now.to_i.to_s(:number) + '.zip'
      zip_file = File.new(Rails.root.join('public', 'delete', directory_name, @zip_name.to_s), 'w')
      files_array.each do |f|
        file = if enc_or_dec == 'true'
                 f + '.enc'
               else
                 f[0...-4]
               end
        Zip::File.open(zip_file.path, Zip::File::CREATE) do |zip|
          zip.add(file, Rails.root.join('public', 'uploads', file))
        end
        File.delete(Rails.root.join('public', 'uploads',
                                    file))
      end
      mime_type = Rack::Mime.mime_type(File.extname(@zip_name))
      send_file Rails.root.join('public', 'delete', 
                                directory_name, @zip_name), 
                type: "application/#{mime_type}", 
                filename: @zip_name
    else
      files_array[0] = if enc_or_dec == 'true'
                         files_array[0] + '.enc'
                       else
                         files_array[0][0...-4]
                       end
      mime_type = 'octet-stream'
      FileUtils.mv(Rails.root.join('public', 'uploads',
                                   files_array[0]), Rails.root.join('public', 'delete', directory_name,
                                                                    files_array[0]))
      send_file Rails.root.join('public', 'delete', directory_name,
                                files_array[0]),
                type: "application/#{mime_type}",
                filename: files_array[0]
    end
  end

  def upload
    uploaded_pics = params[:file]
    session[:files] = ''
    uploaded_pics.each do |file|
      time_footprint = Time.now.to_i.to_s(:number)
      file_original_name = uploaded_pics[file].original_filename
      file_name = time_footprint + uploaded_pics[file].original_filename
      file_name = file_original_name if file_original_name[-4..-1] == '.enc'
      session[:files] += file_name + ', '
      File.open(Rails.root.join('public', 'uploads',
                                file_name), 'wb') do |out|
        out.write(uploaded_pics[file].read)
      end
    end
    render json: { message: 'You have successfully uploded your images.' }
  end

  private

  def encrypt_uploaded_file(file, cipher_value, logged_in)
    cipher = OpenSSL::Cipher::AES.new(cipher_value.to_i, :GCM)
    cipher.encrypt
    key = cipher.random_key
    iv = cipher.random_iv
    cipher.auth_data = ''
    data = ''
    File.open(Rails.root.join('public', 'uploads', file)) { |inf|
      data += inf.read
    }
    File.delete(Rails.root.join('public', 'uploads',
                                file))
    encrypted = cipher.update(data) + cipher.final
    tag = cipher.auth_tag
    if logged_in
      base_key = Base64.encode64(key)
      base_iv = Base64.encode64(iv)
      base_tag = Base64.encode64(tag)
      cipher_new = current_user.crypt_ciphers.build(key: base_key, iv: base_iv,
                                                    tag: base_tag, filename: file + '.enc')
      cipher_new.save
    else
      encrypted += "q1w2e3#{key}e3w2q1#{iv}k08l76#{tag}"
    end

    File.open(Rails.root.join('public', 'uploads', file + '.enc'), 'wb') do |out|
      out.write(encrypted)
    end
  end

  def decrypt_uploaded_file(file, cipher_value, logged_in)
    File.open(Rails.root.join('public', 'uploads', file)) do |inf|
      @encrypted_file = inf.read
    end
    File.delete(Rails.root.join('public', 'uploads',
                                file))
    decipher = OpenSSL::Cipher::AES.new(cipher_value.to_i, :GCM)
    if logged_in
      user_id = current_user.id
      file_data = CryptCipher.where(filename: file, user_id: user_id).first
      decipher.decrypt
      decipher.auth_tag = Base64.decode64(file_data.tag)
      decipher.iv = Base64.decode64(file_data.iv)
      decipher.key = Base64.decode64(file_data.key)
      decipher.auth_data = ''
      file_data.destroy
      data = decipher.update(@encrypted_file) + decipher.final
      File.open(Rails.root.join('public', 'uploads', file[0...-4]), 'wb') { |out|
        out.write(data)
      }
    else
      decipher.decrypt
      decipher.auth_tag = find_tag(@encrypted_file)
      decipher.iv = find_iv(@encrypted_file)
      decipher.key = find_key(@encrypted_file)
      decipher.auth_data = ''
      data = decipher.update(@encrypted_file) + decipher.final
      File.open(Rails.root.join('public', 'uploads', file[0...-4]), 'wb') { |out|
        out.write(data)
      }
    end
  end

  def find_tag(string)
    i = 0
    b = -5
    loop do
      i -= 1
      b -= 1
      next unless string[b..i].eql?('k08l76')
      i += 1
      tag = string[i..-1]
      @encrypted_file = string[0...b]
      return tag
    end
  end

  def find_iv(string)
    i = 0
    b = -5
    loop do
      i -= 1
      b -= 1
      next unless string[b..i].eql?('e3w2q1')
      i += 1
      iv = string[i..-1]
      @encrypted_file = string[0...b]
      return iv
    end
  end

  def find_key(string)
    i = 0
    b = -5
    loop do
      i -= 1
      b -= 1
      next unless string[b..i].eql?('q1w2e3')
      i += 1
      key = string[i..-1]
      @encrypted_file = string[0...b]
      return key
    end
  end

  def clear_when_five_minute_pass
    Dir.glob("#{Rails.root.join('public', 'delete')}/*") do |rb_file|
      rb_file.slice!("#{Rails.root.join('public', 'delete')}/")
      if Time.now.to_i - rb_file.to_i > 5.minutes.to_i
        FileUtils.rm_r Rails.root.join('public', 'delete',
                                       rb_file)
      end
    end
  end
end
