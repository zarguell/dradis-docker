class QA::IssuesController < AuthenticatedController
  include ActivityTracking
  include LiquidEnabledResource
  include Mentioned
  include ProjectScoped

  before_action :set_issues
  before_action :set_issue, only: [:edit, :show, :preview, :update]
  before_action :validate_state, only: [:multiple_update, :update]

  def index
    @all_columns = @default_columns = ['Title']
  end

  def show; end

  def edit
    @form_cancel_path = project_qa_issue_path(current_project, @issue)
    @form_preview_path = preview_project_qa_issue_path(current_project, @issue)
    @tags = current_project.tags
  end

  def update
    if @issue.update(state: @state, updated_at: Time.now)
      track_state_change(@issue)
      redirect_to project_qa_issues_path(current_project), notice: 'State updated successfully.'
    else
      render :show, alert: @issue.errors.full_messages.join('; ')
    end
  end

  def multiple_update
    @issues = current_project.issues.where(id: params[:ids])

    respond_to do |format|
      if @issues.update_all(state: @state, updated_at: Time.now)

        @issues.each do |issue|
          track_state_change(issue)
        end

        format.html do
          if params[:return_to] == 'qa'
            redirect_to project_qa_issues_path(current_project), notice: 'State updated successfully.'
          else
            redirect_to project_issues_path(current_project), notice: 'State updated successfully.'
          end
        end

        format.json { head :ok }
      else
        format.html { render :show, alert: @issues.errors.full_messages.join('; ') }
        format.json { head :not_found }
      end
    end
  end

  private

  def issue_params
    params.permit(:state)
  end

  def liquid_resource_assigns
    { 'issue' => IssueDrop.new(@issue) }
  end

  def set_issue
    @issue = @issues.find(params[:id])
  end

  def set_issues
    @issues = current_project.issues.ready_for_review
  end

  def validate_state
    if Issue.states.keys.include?(params[:state])
      @state = params[:state]
    else
      redirect_to project_qa_issues_path(current_project), alert: 'Something fishy is going on...'
    end
  end
end
