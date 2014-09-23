class TimesheetController < ApplicationController
  unloadable

  layout 'base'
  before_filter :get_list_size
  before_filter :get_precision
  before_filter :get_activities

  helper :sort
  include SortHelper
  helper :issues
  include ApplicationHelper
  helper :timelog

  SessionKey = 'timesheet_filter'

#  verify :method => :delete, :only => :reset, :render => {:nothing => true, :status => :method_not_allowed }

  def index
    load_filters_from_session
    unless @timesheet
      @timesheet ||= Timesheet.new
    end
    @timesheet.allowed_projects = allowed_projects

    if @timesheet.allowed_projects.empty?
      render :action => 'no_projects'
      return
    end
  end

  def clients
    #load_filters_from_session_client
    if params && params[:timesheet]
      if params[:timesheet][:users].nil?
        params[:timesheet][:users] = []
      end
      if params[:timesheet][:groups].nil?
        params[:timesheet][:groups] = []
      end

      #@allparams = params
      @timesheet = Timesheet.new( params[:timesheet] )
    else
      @timesheet = Timesheet.new
    end

    @timesheet.allowed_projects = allowed_projects
    @timesheet.allowed_clients = allowed_clients

    if @timesheet.allowed_clients.empty?
      render :action => 'no_projects'
      return
    end

    if params && params[:timesheet]
      if !params[:timesheet][:clients].nil?
        params[:timesheet][:projects] = []
      end

      if !params[:timesheet][:clients].blank?
        @timesheet.clients = @timesheet.allowed_clients.find_all do |client|
          params[:timesheet][:clients].include?(client.id.to_s)
        end

        @timesheet.projects = []
        @timesheet.clients.each do |client|
          fit_allowed_projects = @timesheet.allowed_projects.find_all do |project|
            client.projects_ids.include?(project.id)
          end

          @timesheet.projects.concat(fit_allowed_projects)
        end

      else
        @timesheet.clients = @timesheet.allowed_clients
        @timesheet.projects = @timesheet.allowed_projects
      end

      call_hook(:plugin_timesheet_controller_report_pre_fetch_time_entries, { :timesheet => @timesheet, :params => params })
      #save_filters_to_session_client(@timesheet)
      #@timesheet.fetch_time_entries_by_project

      @timesheet.fetch_time_entries_by_project_client

      respond_to do |format|
        format.html { render :action => 'clients', :layout => false if request.xhr? }
        format.csv  { send_data @timesheet.to_csv_client, :filename => 'timesheetClient.csv', :type => "text/csv" }
      end
    end
  end

  def report
    if params && params[:timesheet]
      @timesheet = Timesheet.new(params[:timesheet])
    else
      redirect_to :action => 'index'
      return
    end

    @timesheet.allowed_projects = allowed_projects

    if @timesheet.allowed_projects.empty?
      render :action => 'no_projects'
      return
    end

    if !params[:timesheet][:projects].blank?
      @timesheet.projects = @timesheet.allowed_projects.find_all { |project|
        params[:timesheet][:projects].include?(project.id.to_s)
      }
    else
      @timesheet.projects = @timesheet.allowed_projects
    end

    call_hook(:plugin_timesheet_controller_report_pre_fetch_time_entries, { :timesheet => @timesheet, :params => params })

    save_filters_to_session(@timesheet)

    @timesheet.fetch_time_entries

    # Sums
    @total = { }
    unless @timesheet.sort == :issue
      @timesheet.time_entries.each do |project,logs|
        @total[project] = 0
        if logs[:logs]
          logs[:logs].each do |log|
            @total[project] += log.hours
          end
        end
      end
    else
      @timesheet.time_entries.each do |project, project_data|
        @total[project] = 0
        if project_data[:issues]
          project_data[:issues].each do |issue, issue_data|
            @total[project] += issue_data.collect(&:hours).sum
          end
        end
      end
    end

    @grand_total = @total.collect{|k,v| v}.inject{|sum,n| sum + n}

    if params[:timesheet][:summary]
      calculate_summary
      render :action => :summary
    else
      respond_to do |format|
        format.html { render :action => 'details', :layout => false if request.xhr? }
        format.csv  { send_data @timesheet.to_csv, :filename => 'timesheet.csv', :type => "text/csv" }
      end
    end
  end

  def context_menu
    @time_entries = TimeEntry.find(:all, :conditions => ['id IN (?)', params[:ids]])
    render :layout => false
  end

  def reset
    clear_filters_from_session
    redirect_to :action => 'index'
  end

  private

  def calculate_summary
    @summary = {}
    # NON-BILLABLE ACTIVITIES:
    #enums = Enumeration.find([257,175,258,191,192,193,194,195,196,259,213,214,215])
    #[175, 191, 192, 193, 194, 195, 196, 213, 214, 215, 257, 258, 259]
    #["Infrastracture", "Reporting", "Meeting2", "Corp. event", "Evaluation", "Training", "Business trip", "Holidays", "SickDays", "DayOff", "NoTask", "Estimation", "Vacation2"]
    activities = {
      'all_non_billable' => [257,175,258,191,192,193,194,195,196,259,213,214,215,7562],
      'vacation' => [259,7562],
      'sick' => [214],
      'holydays_and_dayoff' => [213,215],
    }
    @timesheet.time_entries.each do |user, logs|
      user_hours = {
        'total' => 0,
        'work' => 0,
        'vacation' => 0,
        'sick' => 0,
        'holydays_and_dayoff' => 0,
        'issues_and_process' => 0,
      }
      logs[:logs].each do |row|
        user_hours['total'] += row[:hours]
        unless activities['all_non_billable'].include?(row[:activity_id])
          user_hours['work'] += row[:hours]
        else
          if activities['vacation'].include?(row[:activity_id])
            user_hours['vacation'] += row[:hours]
          elsif activities['sick'].include?(row[:activity_id])
            user_hours['sick'] += row[:hours]
          elsif activities['holydays_and_dayoff'].include?(row[:activity_id])
            user_hours['holydays_and_dayoff'] += row[:hours]
          else
            user_hours['issues_and_process'] += row[:hours]
          end
        end
      end

      @summary = @summary.merge(user => user_hours)
    end
  end

  def get_list_size
    @list_size = Setting.plugin_redmine_timesheet_plugin['list_size'].to_i
  end

  def get_precision
    precision = Setting.plugin_redmine_timesheet_plugin['precision']

    if precision.blank?
      # Set precision to a high number
      @precision = 10
    else
      @precision = precision.to_i
    end
  end

  def get_activities
    @activities = TimeEntryActivity.all(:conditions => 'parent_id IS NULL')
  end


  def clear_filters_from_session
    session[SessionKey] = nil
  end

  def load_filters_from_session
    if session[SessionKey]
      @timesheet = Timesheet.new(session[SessionKey])
      @timesheet.period_type = Timesheet::ValidPeriodType[:default]
    end

    if session[SessionKey] && session[SessionKey]['projects']
      @timesheet.projects = allowed_projects.find_all { |project|
        session[SessionKey]['projects'].include?(project.id.to_s)
      }
    end
  end

  def save_filters_to_session(timesheet)
    if params[:timesheet]
      # Check that the params will fit in the session before saving
      # prevents an ActionController::Session::CookieStore::CookieOverflow
      encoded = Base64.encode64(Marshal.dump(params[:timesheet]))
      if encoded.size < 2.kilobytes # Only use 2K of the cookie
        session[SessionKey] = params[:timesheet]
      end
    end

    if timesheet
      session[SessionKey] ||= {}
      session[SessionKey]['date_from'] = timesheet.date_from
      session[SessionKey]['date_to'] = timesheet.date_to
    end
  end

  def allowed_projects
    @_allowed_projects ||= begin
      if User.current.admin?
        Project.find(:all, :order => 'name ASC')
      else
        Project.find(:all, :conditions => Project.visible_condition(User.current), :order => 'name ASC')
      end
    end
  end

  def allowed_clients
    @_allowed_clients ||= Clienttimesheet.new.get_all_clients(allowed_projects)
  end

end
