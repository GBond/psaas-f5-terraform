#!/usr/bin/python
import subprocess
import time
import datetime
import os
import sys

start_time = datetime.datetime.now()

emailid = sys.argv[1]
git_cmd = sys.argv[2]
shortUrl = os.getenv('shortUrl')

cmd = ["docker","run","-it","-d", "-e", "emailid=%s" %(emailid),"-e", "TF_VAR_bigiqLicenseManager=null",
       "-e", "SNOPS_AUTOCLONE=0","-e", "shortUrl=%s" %(shortUrl), "f5devcentral/f5-super-netops-container:base"]

docker_id = subprocess.check_output(cmd).strip()
#docker_id = "7e1b7cb4c009dc0fdc1df6b5e29af53893ce18525f73b4657dda1cbb3986301f"
print  docker_id
# change for your repo
shell_cmd = "cd ~;%s" %(git_cmd)
cmd = ["docker","exec","-it",docker_id,"bash", "-c", shell_cmd]
output = subprocess.check_output(cmd)
print output

shell_cmd = "cd ~/marfil-f5-terraform;source ./start;"
cmd = ["docker","exec","-it",docker_id,"bash", "-c", shell_cmd]
output = subprocess.check_output(cmd)
print output

cmd = ["docker","exec","-it",docker_id,"bash", "-c", "source ~/.profile &> /dev/null;cd ~/marfil-f5-terraform;terraform plan &> plan.log"]
output = subprocess.check_output(cmd)

cmd = ["docker","exec","-it",docker_id,"bash", "-c", "source ~/.profile &> /dev/null;cd ~/marfil-f5-terraform;terraform apply &> apply.log"]
output = subprocess.check_output(cmd)


cmd = ["docker","exec","-it",docker_id,"bash", "-c", "source ~/.profile &> /dev/null;cd ~/marfil-f5-terraform;./scripts/lab-info |grep -c \"System Ready\";"]
count = 0

while count != "3":
    try:
        output = subprocess.check_output(cmd)
    except Exception,e:
        # no output yet
        output = ""
    count = output.strip()
    if count == "3":
       print "all done"
    else:
       print "waiting",count
       time.sleep(60)

#
# cleanup
#
cmd = ["docker","exec","-it",docker_id,"bash", "-c", "source ~/.profile &> /dev/null;cd ~/marfil-f5-terraform;scripts/lab-cleanup"]
output = subprocess.check_output(cmd)

cmd = ["docker","exec","-it",docker_id,"bash", "-c", "source ~/.profile &> /dev/null;cd ~/marfil-f5-terraform;terraform destroy -force &> destroy.log"]
output = subprocess.check_output(cmd)

cmd = ["docker","exec","-it",docker_id,"bash", "-c", "source ~/.profile &> /dev/null;cd ~/marfil-f5-terraform;scripts/deleteBucket.sh"]
output = subprocess.check_output(cmd)
print output

cmd = ["docker","rm","-f",docker_id]
output = subprocess.check_output(cmd)

print "run time",datetime.datetime.now()-start_time
