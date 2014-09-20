if Rails::VERSION::MAJOR >= 3
  RedmineApp::Application.routes.draw do
    match 'timesheet/index' => 'timesheet#index'
    match 'timesheet/context_menu' => 'timesheet#context_menu'
    match 'timesheet/report' => 'timesheet#report'
    match 'timesheet/clients' => 'timesheet#clients'
    match 'timesheet/reset' => 'timesheet#reset', :via => :delete
  end
else
  ActionController::Routing::Routes.draw do |map|
    map.connect 'timesheet/index', :controller => 'timesheet', :action => 'index'
    map.connect 'timesheet/context_menu', :controller => 'timesheet', :action => 'context_menu'
    map.connect 'timesheet/report.:format', :controller => 'timesheet', :action => 'report'
    map.connect 'timesheet/clients.:format', :controller => 'timesheet', :action => 'clients'
    map.connect 'timesheet/reset', :controller => 'timesheet', :action => 'reset', :conditions => { :method => :delete }
  end
end
