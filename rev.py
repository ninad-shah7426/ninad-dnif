
import sys
sys.path.append('/usr/src/nm/core-v9')
from helpers.postgres_helper import postgresHelper
from unet_sync_process.workbook_process import extract

dbobj = postgresHelper(app_name="upgrade_script")

sel_query = "select scope_id from scope_details"
sel_data = dbobj.execute_query(query=sel_query)
scope_id_list = [i['scope_id'] for i in sel_data]

for scope in scope_id_list:
    l_reject, msg = extract(workbooks_path='/usr/src/nm/core-v9/templates/content', scope_id=scope)