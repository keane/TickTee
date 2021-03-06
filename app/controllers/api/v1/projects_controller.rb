class Api::V1::ProjectsController < Api::V1::BaseController
  
  before_action :set_project, :only => [:show, :update, :destroy] 
  
  def index
    respond_with(current_user.projects)
  end
  
  def create
    @project = current_user.projects.build(project_params)
    @project.sync_mode = "I"
    if @project.save
      render json: @project.to_json,  success: true, status: :created
    else
      render json: @project.errors, status: :unprocessable_entity
    end

  end
  
  def show
    respond_with(@project)
  end
  
  def update
    @project.sync_mode = "U"
    if @project.update(project_params)     
      render json: @project.to_json,  success: true, status: :created
    else
      render json: @project.errors, status: :unprocessable_entity
    end
  end
  
  def destroy
    @project.sync_mode = "D"
    @project.save
    public_path = Rails.public_path.to_s
    path = public_path << "/progress/#{@project.name}.jpg"
    img_path = path if File.exists? path
    # @project.destroy
    File.delete(img_path) if File.exist? img_path if img_path
    render json: @project.to_json, status: :ok, success: true
  end
  
  private 
  def project_params
    params.require(:project).permit(:name, :description, :updated_at, :created_at, :start_at, :end_at, :expected_progress, :current_progress, :target, :alert_type, :unit, :is_decimal_unit, :init_progress, :is_consumed, :sync_mode, :schedule)
  end
  
  def set_project
    @project = current_user.projects.find_by_id(params[:id])
    render json: {message: "resource not found"}, status: :not_found unless @project
  end
  
end