from os import listdir
from os.path import isfile, join

onlyfiles = [f for f in listdir("old_instances") if isfile(join("old_instances", f))]

for file in onlyfiles:
    f = open(file)
