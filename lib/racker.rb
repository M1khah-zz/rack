require 'erb'
require 'yaml'
require 'codebreaker'

class Racker
  def self.call(env)
    new(env).response.finish
  end

  def initialize(env)
    @request = Rack::Request.new(env)
    @game = game
    @request.session[:turns] ||= {}
  end

  def sorted_data
    return [] unless data
    data.sort_by { |record| record[:attempts_used] }
  end

  def session_data(data)
    @request.session[data]
  end

  def response
    case @request.path
    when '/'            then Rack::Response.new(render('game.html.erb'))
    when '/code_checker' then code_checker
      when '/restart'     then restart
      when '/hint'        then hint
      when '/save'        then save
      when '/data'     then show_data
      else Rack::Response.new('Not Found', 404)
    end
  end


  def render(template)
    path = File.expand_path("../views/#{template}", __FILE__)
    ERB.new(File.read(path)).result(binding)
  end

  private
  
  def game
    @request.session[:game] ||= Codebreaker::Game.new
  end

  def code_checker
    @request.session[:guess] = @request.params['guess']
    @request.session[:turns][session_data(:guess)] = @game.code_checker(session_data(:guess))
    redirect_to('/')
  end

  def restart
    @request.session.clear
    redirect_to('/')
  end

  def hint
    @request.session[:hint] = @game.hint
    redirect_to('/')
  end

  def save
    File.new('data.yaml', 'w') unless File.exist?('data.yaml')

    data = @game.to_h
    data[:name] = @request.params['name']

    statistics = data || []
    statistics << data

    File.open('data.yaml', "w") do |f|
      f.write(statistics.to_yaml)
    end
    redirect_to('/restart')
  end

  def show_data
    Rack::Response.new(render('data.html.erb'))
  end

  def data
    YAML.load_file('data.yaml')
  end

  def redirect_to(path)
    Rack::Response.new do |response|
      response.redirect(path)
    end
  end
end
