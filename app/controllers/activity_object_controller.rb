class ActivityObjectController < ApplicationController
  
  before_filter :fill_style, :only => [:show_avatar]

  def show_avatar
    respond_to do |format|
      format.any {
        ao = ActivityObject.find_by_id(params[:id])
        unless ao.nil? or ao.object.nil?
          authorize! :show, ao.object
          path = ao.avatar.path(params[:style])
          type = ao.avatar_content_type
          filename = ao.avatar.original_filename
        else
          path = Rails.root.to_s + '/app/assets/images/logos/original/ao-default.png'
          type = "image/png"
          filename = "ao-default.png"
        end

        head(:not_found) and return unless File.exist?(path)

        send_file path,
                 :filename => filename,
                 :disposition => "inline",
                 :type => type #request.format
      }
    end
  end


  private

  def fill_style
    if params[:style].present?
      params[:style] = (Vish::Application.config.available_thumbnail_styles & [params[:style]]).first
    end
    params[:style] = params[:style] || "original"
  end

end