##!/usr/bin/ruby

require 'rubygems'
require 'sinatra'
require 'less'
require 'memcached'
require 'cache'

require './lib/dropbox_connector.rb'    

CONFIG = []
CONFIG['memcached'] = 'localhost:11211'

#result = Sinatra::Cache.cache(cache_key) do
#    this_is_an_expensive_method
#end

class Sinatra::Event
  include CacheableEvent
end

configure do
  puts "Sinatra :: Configure do"
  
  CACHE = Memcached.new
  
  #set :dbname, 'devdb' # Variable set for all blocks
  
  DPC = DropboxConnector.new(  'http://www.wellconsidered.be/', 
                                'config/dropbox-key.txt', 
                                'ysr84fd8hy49v9k', 
                                'oxye3gyi03lqmd4')
                                
  puts "Sinatra :: #{DPC}"
end

def load_gallery(gallery)
  photos = DPC.session.list gallery.path #, {suppress_list: true}
  photos_dir = "./thumbs/" + gallery.path
  
  album = Album.find_or_create_by_path(gallery.path)
  
  if album.modified != album.modified
    puts "Gallery :: Creating #{gallery.path} modified on: #{gallery.modified}" # -> (#{gallery.inspect})"
    
    album.modified = gallery.modified
    album.save
  
    # Heroku is read-only.
    #FileUtils.mkdir_p photos_dir unless File.directory? photos_dir
  
    photos.each do |item|
      if defined? item.mime_type && item.mime_type == "image/jpeg"
        unless photo = album.photos.find_by_path(item.path)
          path = DPC.session.link item.path
          path.sub!(/\/dropbox/, "") # remove dropbox from path for direct linking
        
          photo = album.photos.create(  :name => "#{photos_dir}/#{path.scan(/\w+\.\w+$/)[0]}",
                                        :path => "/#{item.path}", :link => path, 
                                        #:thumb => DPC.session.thumbnail(item.path), # We do this later on
                                        :revision => item.revision, :modified => item.modified)
                                          
          puts "Photo :: Creating #{photo.path} ..."
        end

        # Heroku is read-only. Saving thumnbail in database is enough.
        #unless File.exist? photo.name
        #  puts "Photo :: Saving photo: #{photo.path} modified on: #{photo.modified}"
        #
        #  a = File.new(photo.name, "wb")
        #  a.write(photo.thumb)
        #  a.close
        #end
      end
    
      album.save
    end
  end
end

load 'models.rb'
load 'routes.rb'