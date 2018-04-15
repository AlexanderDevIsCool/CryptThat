class FilesUploadController < ApplicationController

  def new

  end

  def create

  end

  def upload
    uploaded_pics = params[:file] # Take the files which are sent by HTTP POST request.
    time_footprint = Time.now.to_i.to_s(:number) # Generate a unique number to rename the files to prevent duplication
    uploaded_pics.each do |pic|
      File.open(Rails.root.join('public', 'uploads', uploaded_pics[pic].original_filename), 'wb') do |file|
        file.write(uploaded_pics[pic].read)
        File.rename(file, 'public/uploads/' + time_footprint + uploaded_pics[pic].original_filename)
      end
    end
    files_list = Dir['public/uploads/*'].to_json #get a list of all files in the {public/uploads} directory and make a JSON to pass to the server
    render json: { message: 'You have successfully uploded your images.', files_list: files_list } #return a JSON object amd success message if uploading is successful
  end
end
