module TimesheetHelper
  include ProjectsHelper

  def add_day_total? time_entries, time_entry_counter
    (time_entry_counter == (time_entries.length - 1)) ||
      (time_entries[time_entry_counter + 1].spent_on != time_entries[time_entry_counter].spent_on)
  end

  def calculate_day_total time_entries, time_entry_counter
    date = time_entries[time_entry_counter].spent_on
    hours_sum = 0
    while (time_entry_counter >= 0) && (time_entries[time_entry_counter].spent_on == date)
      hours_sum += time_entries[time_entry_counter].hours
      time_entry_counter -= 1
    end
    number_with_precision(hours_sum, :precision => @precision)
  end

  def showing_users(users)
    l(:timesheet_showing_users) + users.collect(&:name).join(', ')
  end

  def showing_activity(entry)
    totalusers = entry[:logs].inject(Hash.new(0)) do |acc, log|
      acc[log.activity.name] += log.hours
      acc
    end

    totalusers.inject([]) do |acc, (name, hours)|
      acc << "%s: %s" % [name, hours]

      acc
    end.join(", ")
  end

  def showing_activity_client (project)
    resultactivity = ""
    totalusers = {}
    alltime =0
    project.each do |nameproj,entry|
      entry[:logs].each do |logs|
        if totalusers[logs.activity.name].nil?
          totalusers[logs.activity.name] = logs.hours
        else
          totalusers[logs.activity.name] += logs.hours
        end
        alltime += logs.hours
      end
    end
    totalusers.each do |name, hours|
      resultactivity += name.to_s + ": " + hours.to_s + "<br>"
    end
    resultactivity << ("<b>All time: " + alltime.to_s + "</b>")

    resultactivity.html_safe
  end

  def permalink_to_timesheet(timesheet)
    link_to(l(:timesheet_permalink),
            :controller => 'timesheet',
            :action => 'report',
            :timesheet => timesheet.to_param)
  end

  def link_to_csv_export(timesheet)
    link_to('CSV',
            {
      :controller => 'timesheet',
      :action => 'report',
      :format => 'csv',
      :timesheet => timesheet.to_param
    },
    :method => 'post',
    :class => 'icon icon-timesheet')
  end

  def toggle_issue_arrows(issue_id)
    js = "toggleTimeEntries('#{issue_id}'); return false;"

    return toggle_issue_arrow(issue_id, 'toggle-arrow-closed.gif', js, false) +
      toggle_issue_arrow(issue_id, 'toggle-arrow-open.gif', js, true)
  end

  def toggle_issue_arrow(issue_id, image, js, hide=false)
    style = "display:none;" if hide
    style ||= ''

    content_tag(:span,
                link_to_function(image_tag(image, :plugin => "redmine_timesheet_plugin"), js),
                :class => "toggle-" + issue_id.to_s,
                :style => style
               )

  end

  def toggle_issue_arrows_date(spent_on)
    js = "toggleTimeEntriesdate('#{spent_on}'); return false;"

    return toggle_issue_arrow_date(spent_on, 'toggle-arrow-closed.gif', js, false) +
      toggle_issue_arrow(spent_on, 'toggle-arrow-open.gif', js, true)
  end

  def toggle_issue_arrow_date(spent_on, image, js, hide=false)
    style = "display:none;" if hide
    style ||= ''

    content_tag(:span,
                link_to_function(image_tag(image, :plugin => "redmine_timesheet_plugin"), js),
                :class => "toggle-" + spent_on.to_s,
                :style => style
               )

  end



  def displayed_time_entries_for_issue(time_entries)
    time_entries.collect(&:hours).sum
  end

  def project_options(timesheet)
    available_projects = timesheet.allowed_projects
    selected_projects = timesheet.projects
    selected_projects = available_projects if selected_projects.blank?
    project_tree_options_for_select(available_projects, :selected => selected_projects)
  end

  def client_options(timesheet)
    available_clients = timesheet.allowed_clients
    selected_clients = timesheet.clients.map(&:id)
    selected_clients = available_clients.map(&:id) if selected_clients.blank?
    options_from_collection_for_select(available_clients, :id, :name, :selected => selected_clients)
  end

  def activity_options(timesheet, activities)
    options_from_collection_for_select(activities, :id, :name, timesheet.activities)
  end

  def group_options(timesheet)
    available_groups = Group.all
    if timesheet.groups.first.class == Group
      selected_groups = timesheet.groups.collect{|g| g.id}
    else
      selected_groups = timesheet.groups
    end
    selected_groups = available_groups.collect{|g| g.id} if selected_groups.blank?
    options_from_collection_for_select(available_groups, :id, :name, :selected =>timesheet.groups)
  end

  def user_options(timesheet)
    available_users = Timesheet.viewable_users.sort { |a,b| a.to_s.downcase <=> b.to_s.downcase }
    selected_users = timesheet.users

    options_from_collection_for_select(available_users,
                                       :id,
                                       :name,
                                       selected_users)

  end

  def link_to_csv_export_client(timesheet)
    link_to('CSV',
            {
                :controller => 'timesheet',
                :action => 'clients',
                :format => 'csv',
                :timesheet => timesheet.to_param
            },
            :method => 'post',
            :class => 'icon icon-timesheet')
  end

  def permalink_to_timesheet_client(timesheet)
    link_to(l(:timesheet_permalink),
            :controller => 'timesheet',
            :action => 'clients',
            :timesheet => timesheet.to_param)
  end

end
