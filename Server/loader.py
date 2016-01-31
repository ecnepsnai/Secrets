from google.appengine.tools import bulkloader
from google.appengine.ext import db
import datetime
import logging
import sys


class Secret(db.Model):
  bundle = db.StringProperty()
  keypath = db.StringProperty()
  icon = db.LinkProperty()


class SecretExporter(bulkloader.Exporter):
  def __init__(self):
    bulkloader.Exporter.__init__(self, 'Secret',
                                 [('bundle', str, None),
                                  ('keypath', str, None)
                                 ])

exporters = [SecretExporter]

# 
# class SecretLoader(bulkload.Loader):
#   def __init__(self):
#     # Our 'Person' entity contains a name string and an email
#     bulkloader.Loader.__init__(self, 'Secret',
#                          [ ('old_id', int),
#                            ('bundle', str),
#                            ('display_bundle', str),
#                            ('keypath', str),
#                            ('datatype', str),
#                            ('title', str),
#                            ('defaultvalue', str),
#                            ('units', str),
#                            ('values', str),
#                            ('hidden', lambda x: (x == '1')),
#                            ('description', datastore_types.Text),
#                            ('notes', datastore_types.Text),
#                            ('widget', str),
#                            ('username', str),
#                            ('hostname', str),
#                            ('minversion', str),
#                            ('maxversion', str),
#                            ('minosversion', str),
#                            ('maxosversion', str),
#                            ('verified', lambda x: (x == '1')),
#                            ('current_host_only', lambda x: (x == '1')),
#                            ('set_for_all_users', lambda x: (x == '1')),
#                            ('has_ui', lambda x: (x == '1')),
#                            ('for_developers', lambda x: (x == '1')),
#                            ('top_secret', lambda x: (x == '1')),
#                            ('is_keypath', lambda x: (x == '1')),
#                            ('created_at', str),
#                            ('updated_at', str),
#                            ('group', str),
#                            ('placeholder', str),
#                            ('deleted', lambda x: (x == '1')),
#                            ('is_broken', lambda x: (x == '1')),
#                            ('dangerous', lambda x: (x == '1'))
#                           ])
# 
#                           
# 
#   def HandleEntity(self, entity):
#     ent = search.SearchableEntity(entity)
#     entity['updated_at'] = datetime.datetime.today()
#     entity['created_at'] = datetime.datetime.today()
#     return entity
# 
# if __name__ == '__main__':
#   bulkload.main(SecretLoader())