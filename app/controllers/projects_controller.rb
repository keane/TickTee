class ProjectsController < ApplicationController
  before_action :authenticate_user!, except: [:generate]
  before_action :set_project, only: [:show, :edit, :update, :destroy, :loadjs]
  skip_before_action :verify_authenticity_token, if: :js_request?
  # GET /projects
  # GET /projects.json
  def index
    @avail_projects = current_user.projects.where("sync_mode != 'D'")
  end
  
  def js_request?
    params[:action] == "generate" && request.format.js?
  end

  # GET /projects/1
  # GET /projects/1.json
  def show
    respond_to do |format|
      format.html do
        @image_path = "/progress/#{@project.name}.jpg?#{'%.6f' % Time.new.to_f}" if @img_path   
      end
    end
  end
  

  # GET /projects/new
  def new
    @project = current_user.projects.build
  end

  # GET /projects/1/edit
  def edit
  end

  # POST /projects
  # POST /projects.json
  def create
    @project = current_user.projects.build(project_params)
    @project.sync_mode = "I"
    respond_to do |format|
      if @project.save
        generate_img
        format.html { redirect_to [current_user, @project], notice: 'Project has been created.' }
        format.json { render :show, status: :created, location: [current_user, @project] }
      else
        format.html { 
          flash[:alert] = "Project has not been created."
          render :new
        }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /projects/1
  # PATCH/PUT /projects/1.json
  def update
    @project.sync_mode = "U"
    respond_to do |format|
      if @project.update(project_params)     
        generate_img   
        format.html { redirect_to [current_user, @project], notice: 'Project was successfully updated.' }
        format.json { render :show, status: :ok, location: [current_user, @project] }
      else
        format.html { render :edit }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /projects/1
  # DELETE /projects/1.json
  def destroy
# @project.destroy
#    respond_to do |format|
#      format.html {
#        if @img_path
#          File.delete(@img_path) if File.exist? @img_path
#        end
#        redirect_to user_projects_url(current_user), notice: 'Project was successfully destroyed.'
#      }
#      format.json { head :no_content }
#    end
    @project.sync_mode = "D"
    @project.save
    respond_to do |format|
     format.html {
       if @img_path
         File.delete(@img_path) if File.exist? @img_path
       end
       redirect_to user_projects_url(current_user), notice: 'Project was successfully destroyed.'
     }
     format.json { head :no_content }
   end
  end
  
  # GET /projects/1/generate
  def generate
    respond_to do |format|
      format.jpg do
        begin
          @project = User.find(params[:user_id]).projects.find(params[:id])   
          public_path = Rails.public_path.to_s
          path = public_path << "/progress/#{@project.name}.jpg"
          @img_path = path if File.exists? path
          if @project.generate_at
            diff_date = @project.generate_at - Time.now.to_date
          else
            diff_date = 1
          end
          if @img_path && !@project.is_updated && diff_date == 0
            File.open(@img_path, 'rb') do |f|
              send_data f.read, type: "image/jpeg", disposition: "inline"
            end
          else
            kit = generate_img
            send_data kit.to_jpg, type: "image/jpeg", disposition: "inline"
          end 
        rescue ActiveRecord::RecordNotFound
          public_path = Rails.public_path.to_s
          path = public_path << "/imageNotFound.jpg"
          File.open(path, 'rb') do |f|
            send_data f.read, type: "image/jpeg", disposition: "inline"
          end
        end
      end
      format.js {render template: 'projects/generate'}
    end
  end
  
  # POST /projects/1/generate
  def generate_post
    begin
      @project = User.find(params[:user_id]).projects.find(params[:id])   
      public_path = Rails.public_path.to_s
      path = public_path << "/progress/#{@project.name}.jpg"
      @img_path = path if File.exists? path
      if @project.generate_at
        diff_date = @project.generate_at - Time.now.to_date
      else
        diff_date = 1
      end
      unless @img_path && !@project.is_updated && diff_date == 0      
        generate_img
      end 
      flash[:notice] = "Generate Successfully!"
      redirect_to user_project_path(current_user, @project)
    rescue ActiveRecord::RecordNotFound
      flash[:alert] = "Project not found!"
      redirect_to user_project_path(current_user, @project)
    end
    
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_project
      @project = current_user.projects.find(params[:id])
      public_path = Rails.public_path.to_s
      path = public_path << "/progress/#{@project.name}.jpg"
      @img_path = path if File.exists? path
    rescue ActiveRecord::RecordNotFound
      flash[:alert] = "Resource requested don't exist"
      redirect_to "/"
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def project_params
      if params[:project][:start_at].present? and params[:project][:end_at].present?
        start_string = "#{params[:project][:start_at]} 00:00:00"
        end_string = "#{params[:project][:end_at]} 23:59:59" 
        params[:project][:start_at] = Time.zone.parse(start_string).utc
        params[:project][:end_at] = Time.zone.parse(end_string).utc
      end
      schedule = 0
      if params[:Mon].present?
        schedule += 1 if params[:Mon].eql? "on"
      end
      if params[:Tue].present?
        schedule += 2 if params[:Tue].eql? "on"
      end
      if params[:Wed].present?
        schedule += 4 if params[:Wed].eql? "on"
      end
      if params[:Thu].present?
        schedule += 8 if params[:Thu].eql? "on"
      end
      if params[:Fri].present?
        schedule += 16 if params[:Fri].eql? "on"
      end
      if params[:Sat].present?
        schedule += 32 if params[:Sat].eql? "on"
      end
      if params[:Sun].present?
        schedule += 64 if params[:Sun].eql? "on"
      end
      params[:project][:schedule] = schedule
      params.require(:project).permit(:name, :description, :start_at, :end_at, :expected_progress, :current_progress, :target, :alert_type, :unit, :is_decimal_unit, :init_progress, :is_consumed, :schedule)
    end
    
    def generate_img       
      @project.generate_image("jpg")
    end
end
