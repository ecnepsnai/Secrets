import cgi
import wsgiref.handlers
import os
import datetime

from google.appengine.api import users
from google.appengine.ext import webapp
from google.appengine.ext import db
from google.appengine.ext.webapp import template
from google.appengine.api import memcache
from google.appengine.ext.db import djangoforms
from google.appengine.ext import search

import xml.etree.cElementTree as ET

class Bundle(db.Model):
  bundle_id = db.StringProperty()
  name = db.StringProperty()
  icon = db.LinkProperty()

DATA_TYPES = (
("Boolean", "boolean"),
("Boolean (Negate)", "boolean-neg"),
("Integer", "integer"),
("Float", "float"),
("String", "string"),
("Bundle Identifier", "bundleid"),
("Font Name", "font"),
("File Path", "path"),
("Rect", "rect"),
("Array", "array"),
("Array (Add)", "array-add"),
("Array (Multi Add)", "array-add-multiple"),
("Dictionary", "dict"),
("Dictionary (Add)", "dict-add"),
("Date", "date"),
("Color", "color"),
("URL", "url")
)

class Secret(search.SearchableModel):
  author = db.UserProperty()
  editor = db.UserProperty()
  old_id = db.IntegerProperty()
  
  bundle = db.StringProperty(verbose_name="Bundle ID")
  display_bundle = db.StringProperty()
  app_reference = db.ReferenceProperty(Bundle)
  keypath = db.StringProperty(verbose_name="Key")
  datatype = db.StringProperty()
  title = db.StringProperty()
  defaultvalue = db.StringProperty(verbose_name="Default Value")
  units = db.StringProperty()
  widget = db.StringProperty()
  username = db.StringProperty()
  hostname = db.StringProperty()
  minversion = db.StringProperty(verbose_name="Min Version")
  maxversion = db.StringProperty(verbose_name="Max Version")
  minosversion = db.StringProperty(verbose_name="Min OS Version")
  maxosversion = db.StringProperty(verbose_name="Max OS Version")
  group = db.StringProperty()
  placeholder = db.StringProperty()
  source_url = db.StringProperty()
  values = db.StringProperty(multiline=True)
  description = db.StringProperty(multiline=True)
  notes = db.StringProperty(multiline=True)
  
  hidden = db.BooleanProperty()
  verified = db.BooleanProperty()
  current_host_only = db.BooleanProperty()
  set_for_all_users = db.BooleanProperty()
  has_ui = db.BooleanProperty()
  for_developers = db.BooleanProperty()
  top_secret = db.BooleanProperty()
  is_keypath = db.BooleanProperty()
  deleted = db.BooleanProperty(default=False)
  is_broken = db.BooleanProperty()
  dangerous = db.BooleanProperty()
  
  created_at = db.DateTimeProperty(auto_now_add=True)
  updated_at = db.DateTimeProperty(auto_now=True)
  
  def is_editable(self):
    return (datetime.datetime.today() - self.created_at) < datetime.timedelta(minutes=3)
  
  def default_string(self):
    valid = True
    
    if self.is_keypath:
      valid = False
    
    termbundle = self.bundle
    if self.set_for_all_users:
      termbundle = "/Library/Preferences/" + termbundle;
    
    if termbundle == ".GlobalPreferences" or (termbundle == "NSGlobalDomain"):
       termbundle = "-g"
       
    if valid:
      default_string = "defaults "
      
      if (self.current_host_only):
        default_string += "-currentHost "
      
      default_string += "write " + termbundle + " " + self.keypath + " -" + self.datatype + " "
      return default_string;
    else:
      return termbundle + " " + self.keypath + " -" + self.datatype + " "
  
  def remove_string(self):
    return "defaults delete " + bundle + " " + keypath
  
  def display_title(self):
    title = self.title
    
    if title.length == 0:
      title = "(untitled)"
    
    return title
  
  def display_icon(self):
      if self.display_bundle:
        bundle = self.display_bundle
      else:
        bundle = self.bundle
      
      if bundle == ".GlobalPreferences" or bundle == "NSGlobalDomain":
        bundle = "GlobalPreferences"
      bundle = "/images/bundleicons/" + bundle + ".png"
      
      #if not os.path.isfile(bundle):
      #  bundle = "test.png"
      return bundle
  
  def display_app(self):
    bundle = self.bundle
    if bundle:
      bundle = bundle.split('.')[-1]
    
    display_bundle = self.display_bundle
    # if display_bundle:
    #   if (len(display_bundle) > 0):
    #     icon = self.display_bundle
    #     icon = icon.split('/').last
    # if (display_bundle == "prefPane" | display_bundle == "editor"  | display_bundle == "bundle" | display_bundle == "launcher"):
    #    # display_bundle = self.display_bundle.split('.')[-2]
    #    display_bundle = self.display_bundle.split('/')[-1]
    #
    
    if bundle == "GlobalPreferences":
      bundle = "Every App"
    
    if bundle == "kCFPreferencesCurrentApplication":
      bundle = "Any App"
    
    if self.display_bundle:
      bundle = display_bundle.split('.')[-1]
    return bundle
    
    #  def put_value (key, type, xml)
    #
    #     value = eval "self." + key
    #     if (value)
    #         xml.key(key)
    #         xml.string(value)
    #       end
    # end

class SecretForm(djangoforms.ModelForm):
  class Meta:
    model = Secret
    exclude = ['hostname', 'username', 'author', 'editor', 'app_reference', 'old_id']

class PlistSecret(webapp.RequestHandler):
  def get(self):
    self.response.headers['Secrets-Version'] = "1.0.6"
    self.response.headers['Content-Type'] = 'text/xml; charset=utf-8'
    output = memcache.get("plist")
    if output is None:
      plist_content = ''
      secrets = Secret.all()
      secrets.filter('deleted ==', False)
      count = 0;
      for i in range (0, 4):
        some_secrets = secrets.fetch(200, 200*i)
        this_count = len(some_secrets)
        count += this_count
        if this_count == 0:
          break
        plist_content += template.render('plistentry.xml', {'secrets': some_secrets})
      output = template.render('plist.xml', {'plist_content':plist_content})
      memcache.add("plist", output)
      self.response.headers['Cached'] = 'yes'
    self.response.out.write(output)
class TextSecret(webapp.RequestHandler):
  def get(self):
    output = memcache.get("txt")
    self.response.headers['Content-Type'] = 'text; charset=utf-8'
    if output is None:
      plist_content = ''
      secrets = Secret.all()
      secrets.filter('deleted ==', False)
      count = 0;
      for i in range (0, 4):
        some_secrets = secrets.fetch(200, 200*i)
        this_count = len(some_secrets)
        count += this_count
        for secret in some_secrets:
          self.response.out.write('%s\t%s\r' % (secret.bundle, secret.keypath))
        if this_count == 0:
          break

class MainPage(webapp.RequestHandler):
  def get(self):
    
    version = os.environ["CURRENT_VERSION_ID"];
    if (memcache.get("CURRENT_VERSION_ID") != version):
      memcache.flush_all()
      memcache.add("CURRENT_VERSION_ID", version)
      self.response.out.write("<!--version changed, purging caches-->")
      
    query = Secret.all()
    
    showall = self.request.get('show') == 'all'
    showrecent = self.request.get('show') == 'recent'
    showdeleted = self.request.get('show') == 'deleted'
    showapp = self.request.get('showapp')
    search_string = self.request.get('search')
    
    warning = None
    message = None
    title = None
    
    page = self.request.get('page')
    next_page = None;
    prev_page = None;
    cachename = "index-" + self.request.get('show') + "-" + page
    
    if showapp:
      cachename = None
      if (len(showapp) <=3):
	      showapp = None
	      warning = "invalid app or bundle identifier"
    
    if search_string:
      cachename = None
      if (len(search_string) <= 3):
        search_string = None
        warning = "searches must be longer than 3 characters"
    
    if page != None and page != '':
      page = int(page)
      if page > 0:
          prev_page = str(page - 1);
    else:
      page = 0
    next_page = str(page + 1);
    
    output = None
    if not self.request.get('ignorecache') and cachename:
      output = memcache.get(cachename)
    if output is not None:
      self.response.out.write("<!--loaded from cache-->")
      self.response.out.write(output)
      #self.response.out.write(memcache.get_stats())
    else:
      query.filter('deleted ==', False)
      if showrecent == True:
        title = "Recent Secrets"
        query = db.GqlQuery("SELECT * FROM Secret WHERE deleted = False "
                            "ORDER BY created_at DESC")
        secrets = query.fetch(30)
      elif showall == True:
        title = "All Secrets: page %d" % (page + 1)
        query = db.GqlQuery("SELECT * FROM Secret WHERE deleted = False "
                              "ORDER BY created_at DESC")
        secrets = query.fetch(100, 100 * page)
      elif showdeleted == True:
        title = "All Secrets: page %d" % (page + 1)
        query = db.GqlQuery("SELECT * FROM Secret WHERE deleted = True "
                              "ORDER BY created_at DESC")
        secrets = query.fetch(100, 100 * page)

      elif showapp is not None and len(showapp) > 5:
        title = "\"%s\"" % (showapp)
        query = db.GqlQuery("SELECT * FROM Secret WHERE bundle = '%s'" % showapp)
        secrets = query.fetch(100)
        count = len(secrets)
        if (count is None):
          warning = "no matches"

      elif search_string is not None and len(search_string) > 3:
        title = "\"%s\"" % (search_string)
        query = Secret.all().search(search_string)
        # query = db.GqlQuery("SELECT * FROM Secret WHERE deleted = False"
        #                     "AND bundle = :1"
        #                     "ORDER BY created_at DESC",
        #                     )
        secrets = query.fetch(100)
        count = len(secrets)
        if (count):
          message = '%(number)d secret(s) found for %(search_string)s' % {'search_string': search_string, "number": count }
        else:
          message = "no matches"
      else:
        query.filter('top_secret =', True)
        #query.order('bundle')
        secrets = query.fetch(100, 100 * page)
      
      template_values = {'secrets': secrets,
                         'warning': warning,
                         'search_string' : search_string,
                         'message': message,
                         'title': title,
                         'showall': showall,
                         'next_page': next_page,
                         'prev_page': prev_page}
      
      path = os.path.join(os.path.dirname(__file__), 'index.html')
      output = template.render('index.html', template_values)
      if cachename is not None:
        memcache.add(cachename, output)
      self.response.out.write(output)

class DeleteSecret(webapp.RequestHandler):
  def post(self):
    if (users.is_current_user_admin()):
      id = self.request.get('_id')
      item = Secret.get(db.Key.from_path('Secret', int(id)))
      item.deleted = True
      item.put()
      memcache.flush_all()
      self.redirect('/')

class EditSecret(webapp.RequestHandler):
  def get(self):
    if users.get_current_user():
      url = users.create_logout_url(self.request.uri)
      loggedin = 1
    else:
      url = users.create_login_url(self.request.uri)
      loggedin = 0
    isadmin = users.is_current_user_admin()
    id = self.request.get('id')
    template_values = {
      'id':id,
      'isadmin':isadmin,
      'loggedin':loggedin,
      'url': url
    }
    
    item = None
    if id:
      item = Secret.get(db.Key.from_path('Secret', int(id)))
      if item == None:
        
        self.response.out.write("Unknown secret. <a href=\"/\">Show all.</a>")
        return;
      isowned = (item.author != None) and (item.author == users.get_current_user());
      template_values['isowned'] = isowned
      template_values['iseditable'] = isadmin | isowned | (item.is_editable() & loggedin)
      template_values['form'] = SecretForm(instance=item)
      template_values['secret'] = item
      if item.author:
        template_values['author'] = item.author.nickname().split('@')[0]
      if item.editor:
        template_values['editor'] = item.editor.nickname().split('@')[0]
    else:
      template_values['form'] = SecretForm()
      template_values['iseditable'] = loggedin
    
    self.response.out.write(template.render('form.html', template_values))
  
  def post(self):
    id = self.request.get('_id')
    dups = None
    if id:
      item = Secret.get(db.Key.from_path('Secret', int(id)))
      data = SecretForm(data=self.request.POST, instance=item)
    else:
      dups = db.GqlQuery("SELECT * FROM Secret WHERE bundle = :1 "
                          "AND keypath = :2 ",
                          self.request.get('bundle'), self.request.get('keypath'))
      data = SecretForm(data = self.request.POST)
      self.response.out.write(dups.count())
      
    
    if data.is_valid() and (dups == None or dups.count() == 0):
      # Save the data, and redirect to the view page
      entity = data.save(commit=False)
      if not id:
          entity.author = users.get_current_user()
      entity.editor = users.get_current_user()
      entity.put()
      self.redirect('/')
      memcache.flush_all()
    else:
      # Reprint the form
      if id:
        self.response.out.write(template.render('form.html', {'form':data, 'id':id}))
      else:
        self.response.out.write(template.render('form.html', {'form':data, 'dups':dups}))

class FlushSecrets(webapp.RequestHandler):
  def get(self):
    if (users.is_current_user_admin()):
      secrets = Secret.all().filter("deleted = ", True).fetch(1000)
      self.response.out.write("Flushed %(page)d" % {'page': len(secrets)})
      memcache.flush_all()

class DeleteSecrets(webapp.RequestHandler):
  def get(self):
    if (users.is_current_user_admin()):
      secrets = Secret.all().filter("deleted = ", True).fetch(1000)
      self.response.out.write("Deleted %(page)d" % {'page': len(secrets)})
      db.delete(secrets)
      memcache.flush_all()

class PrintEnvironmentHandler(webapp.RequestHandler):
  def get(self):
    if (users.is_current_user_admin()):
      for name in os.environ.keys():
        self.response.out.write("%s = %s<br />\n" % (name, os.environ[name]))

class RSSNewSecret(webapp.RequestHandler):
  def get(self):
    output = memcache.get("rss-new")
    if output is None:
      secrets = Secret.all().order('-created_at').fetch(20)
      output = template.render("rss.xml", {'secrets':secrets, 'title': 'Recently Added'})
      memcache.add("rss-new", output)
    
    # self.response.headers['Content-Type'] = 'text/rss+xml; charset=utf-8'
    self.response.out.write(output)

class RSSUpdatedSecret(webapp.RequestHandler):
  def get(self):
    output = memcache.get("rss-updated")
    if output is None:
      secrets = Secret.all().order('-updated_at').fetch(20)
      output = template.render("rss.xml", {'secrets':secrets, 'title': 'Recently Updated'})
      memcache.add("rss-updated", output)
    
    self.response.headers['Content-Type'] = 'text/rss+xml; charset=utf-8'
    self.response.out.write(output)

class Backup(webapp.RequestHandler):
  def get(self):
    secrets = Secret.all()
    page = self.request.get('page')
    if page is not None and len(page):
      page = int(page)
    else:
      page = 0
    some_secrets = secrets.fetch(30, 30*page)
    this_count = len(some_secrets)
    for secret in some_secrets:
      secret.put()
    if (this_count > 0):
      url = "<meta http-equiv=\"refresh\" content=\"1;url=/backup?page=%(page)d\"/>" % {'page': int(page)+1}
      self.response.out.write(url)
      self.response.out.write("Next...")
    else:
      self.response.out.write("Done")

class Backup(webapp.RequestHandler):
  def get(self):
    secrets = Secret.all()
    page = self.request.get('page')
    if page is not None and len(page):
      page = int(page)
    else:
      page = 0
    some_secrets = secrets.fetch(30, 30*page)
    this_count = len(some_secrets)
    for secret in some_secrets:
      secret.put()
    if (this_count > 0):
      url = "<meta http-equiv=\"refresh\" content=\"1;url=/backup?page=%(page)d\"/>" % {'page': int(page)+1}
      self.response.out.write(url)
      self.response.out.write("Next...")
    else:
      self.response.out.write("Done")

def main():
  application = webapp.WSGIApplication(
                                       [('/rss/updated', RSSUpdatedSecret),
                                        ('/rss/new', RSSNewSecret),
                                        ('/delete',DeleteSecret),
                                        ('/edit', EditSecret),
                                        ('/txt', TextSecret),
                                        ('/plist', PlistSecret),
                                        ('/env', PrintEnvironmentHandler),
                                        # ('/backup', Backup),
                                        ('/flush', FlushSecrets),
                                        ('/', MainPage)],
                                       debug=True)
  wsgiref.handlers.CGIHandler().run(application)

if __name__ == "__main__":
  main()