#!/usr/bin/env python2.6

from Queue import Queue
from threading import Thread
import urllib2 
import time
import datetime
import fcntl
import sys
import re
import string
import MySQLdb as mdb


class Worker(Thread):
    """Thread executing tasks from a given tasks queue"""
    def __init__(self, tasks):
        Thread.__init__(self)
        self.tasks = tasks
        self.daemon = True
        self.start()
    
    def run(self):
        while True:
            func, args, kargs = self.tasks.get()
            try: func(*args, **kargs)
            except Exception, e: 
                
                localtime=time.localtime(time.time())
                # build the logger message
                # todo:  use the logger class 
                toutput = "%s,%d,%d:%02d:%02d,%s\n" % (args[0], -1, localtime[3],localtime[4],localtime[5],e )

                output_pool.add_task( write_log, toutput)
                output_pool.wait_completion()

            self.tasks.task_done()

class ThreadPool:
    """Pool of threads consuming tasks from a queue"""
    def __init__(self, num_threads):
        self.tasks = Queue(num_threads)
        for _ in range(num_threads): Worker(self.tasks)

    def add_task(self, func, *args, **kargs):
        """Add a task to the queue"""
        self.tasks.put((func, args, kargs))

    def wait_completion(self):
        """Wait for completion of all the tasks in the queue"""
        self.tasks.join()




class AppTest:
    #url = ''
    #frequency = 0
    def __init__(self, url, frequency):
        self.url = url
        self.frequency = frequency

    def dump( self, level ):
        print "  url %s frequency %d" % (self.url, self.frequency)

class AppInstance:
    """ A Class populated with world data from the various copies of the master db"""
    
    def __init__(self,servername, number, status ):
        self.tests = []
        self.name = servername
        self.number = number
        self.status = status

    def add_test(self, frequency, testsuffix, world, testprefix):
        """ add the test to the test list of the world. """
        #print "plink"
        #print "%s%s.%s" % (testprefix, self.number, testsuffix)
        
        lcltest = AppTest("%s%s.%s" % (testprefix, self.number, testsuffix), frequency)
        self.tests.append( lcltest )
        
    def get_test_for_this_minute( self, this_minute, world):
        url_strings = []
        for t in self.tests:
            if (this_minute == 0):
                if t.frequency == 1:
                    url_strings.append ( t.url)

            if (this_minute % t.frequency ) == 0:
                url_strings.append ( t.url)
        return url_strings



    def dump( self, level=1):
        print "self.name = %s" %(self.name)
        print "self.number = %s" %(self.number)
        print "self.status = %s" %(self.status)

        if level >=3:
            for test in self.tests:
                test.dump(level)


class App:
    """ A App - DB details, worlds etc. """
    host = ""
    port = 0
    user = ""
    passwd = ""
    dbname = ""
    glist = []
    
    def __init__( self, host, port, user, passwd, dbname):
        self.host = host
        self.port = int( port )
        self.user = user
        self.passwd = passwd
        self.dbname = dbname
        self.glist = []

    def load(self, type = 'all'):
        self.glist = []

        if type == 'dau':
            query = 'select serverName, serverStatus from server'
        elif type == 'rev':
            query = 'select serverName, serverStatus from server'
        else:
            query = 'select serverName, serverStatus from server'

        try:
            conn = mdb.connect( host=self.host, port=self.port, user=self.user, passwd=self.passwd, db=self.dbname)
            #conn = mdb.connect( host,user,passwd,dbname)
            cursor = conn.cursor()
        
            cursor.execute( query )
            
            p = re.compile('[A-Za-z]*')
            rows = cursor.fetchall()
            self.worldcount = 0
            for row in rows:
                w = AppInstance(row[0], p.sub('', row[0]), row[1])
                self.glist.append( w )
                self.worldcount += 1
            
            cursor.close
            conn.close
            
        except mdb.Error, e:
            print "Error %d: %s" % (e.args[0], e.args[1])
            sys.exit(1)

    def add_test(self, frequency, testsuffix, world=0, testprefix="http://www"):
        if int(world) == 0:
            #print "eeky!  %s" % ( world )
            for i in self.glist:

                i.add_test( frequency, testsuffix, world, testprefix )
        else:
            print "world %d" %( world )
            for i in self.glist:
                print "tweet %d" % ( int(i.number))
                if int(i.number) == int(world):
                    print "world %s" % ( world )
                    i.add_test( frequency, testsuffix, i, testprefix )
                    
    def get_test_for_this_minute( self, this_minute, world = 0):
        url_strings = []
        if int(world) == 0:
            for i in self.glist:
                for t in  i.get_test_for_this_minute( this_minute, i):
                    url_strings.append(t)
                
        else:
            for i in self.glist:
                if  int(i.number) == int(world):
                    for t in  i.get_test_for_this_minute( this_minute, i):
                        url_strings.append( t )
        return url_strings
                                        
       
    
    def dump(self, level=1):
        print "host = %s" %( self.host )
        print "user = %s" %( self.user )
        print "passwd = %s" %( self.passwd )
        print "dbname = %s" %( self.dbname )

        if level >= 2:
            #print "glist = %s" %( self.glist )
            for world in self.glist:
                world.dump(level)

def write_log( s ):
    """Function for writing a record to the log file - used by worker thread."""
    today = datetime.date.today()
    logfile = "logger_%s.out" % ( today, )
    
    # this exception catching is a little over the top, but it was inplace to catch
    # a bug where it seemed that there was an fd leak
    # open and lock the file
    try:
        f = open( logfile, 'a')
    except IOError,err:
        print "IOError:",err
        print "idx=%s"%idx
        print "open - Cannot open %(logfile)"
        sys.exit(1)
        
    try:
        fcntl.flock(f, fcntl.LOCK_EX)
    except IOError,err:
        print "IOError:",err
        print "idx=%s"%idx
        print "lock - Cannot open %(logfile)"
        sys.exit(1)
            
    try:
        f.write( s )
    except IOError,err:
        print "IOError:",err
        print "idx=%s"%idx
        print "write - Cannot open %(logfile)"
        sys.exit(1)
        
        # unlock the file.
        fcntl.flock(f, fcntl.LOCK_UN)
    try:
        f.close()
    except IOError,err:
        print "IOError:",err
        print "idx=%s"%idx
        print "write - Cannot open %(logfile)"
        sys.exit(1)
                    
    
def launch_tests(games, curmin):
    def get_url(u, w, op):
        testworld = u
        world = int(w)
        out_pool = op

        #grabs urls of hosts and then grabs chunk of webpage
        auth_handler = urllib2.HTTPBasicAuthHandler()
        auth_handler.add_password(realm='Authorized personnel only',
                                  uri=testworld,
                                  user='monitor',
                                  passwd='153tvloop')

        opener = urllib2.build_opener(auth_handler)
        urllib2.install_opener(opener)
        opener.addheaders = [('User-agent', 'Mozilla/5.0')]
        
        url = opener.open(testworld,None,5 )
        print "%s %s" % (testworld, world)

        chunk = url.read()
        lines = chunk.split('\n')

        for line in lines:
            if len(line) != 0:
                line = line.rstrip('\n')
                line = line.lstrip('\n')
                localtime=time.localtime(time.time())
                toutput = "%s,%d,%d:%02d:%02d,%s\n" % (testworld, world, localtime[3],localtime[4],localtime[5],line)
                print "|%s|" % (line, )
                
                op.add_task( write_log, toutput)
                op.wait_completion()
                break
            url.close()


            
    for g in games:
        p = re.compile('[A-Za-z:/]*')

        for u in g.get_test_for_this_minute(curmin, 0):
            s = string.split(u,'.',1)
            w = p.sub('', s[0])
            worker_pool.add_task(get_url, u, w, output_pool)



        
worker_pool = ThreadPool(80)
output_pool = ThreadPool(12)

if __name__ == '__main__':
    
    start= time.time()


    # Use a ThreadPool
    # hrmm  taken out as it didn't work
    #    check_loop_pool = ThreadPool(1)

    camelot = App( '10.200.1.167', '3306', 'cboatwright', 'cbee666','CamelotMaster')
    camelot.load()

    camelot.add_test(frequency=1,testsuffix="kingdomsofcamelot.com/fb/e2/src/admin/statusCache.php?csv=1" , world=0)
    camelot.add_test(frequency=1,testsuffix="kingdomsofcamelot.com/fb/e2/src/admin/statusDatabase.php?csv=1" , world=0)
    camelot.add_test(frequency=15,testsuffix="kingdomsofcamelot.com/fb/e2/src/admin/statusFacebook.php?csv=1" , world=0)

    gw = App('10.200.1.168', '3312',  'wcdbuserread', 'ROwcdbu1!', 'gwmaster')
    gw.load()
    #gw.add_test(frequency=1, testsuffix="globalwarfaregame.com/admin/statusCache.php?csv=1" , world=0)
    gw.add_test(frequency=1, testsuffix="globalwarfaregame.com/admin/statusDatabase.php?csv=1" , world=0)
    #gw.add_test(frequency=15, testsuffix="globalwarfaregame.com/admin/statusFacebook.php?csv=1" , world=0)

    glory = App('10.200.1.168', '3308', 'wcdbuserread', 'ROwcdbu1!', 'GoRMaster')
    glory.load()
    glory.add_test(frequency=1, testsuffix="gloryofrome.com/admin/statusCache.php?csv=1" , world=0)
    glory.add_test(frequency=1, testsuffix="gloryofrome.com/admin/statusDatabase.php?csv=1" , world=0)
    glory.add_test(frequency=1, testsuffix="gloryofrome.com/admin/statusFacebook.php?csv=1" , world=0)




    samurai = App('10.200.1.168', '3321', 'wcdbuserread', 'ROwcdbu1!','samurai_master' )
    samurai.load()
    samurai.add_test(frequency=1, testsuffix="samuraidynasty.com/admin/statusCache.php?csv=1" , world=0)

#    game_list = [ camelot, gw, glory, samurai]
    game_list = [ samurai ]

    for g in game_list:
        g.dump(3)

    


    curmin = time.localtime(start)[4]
    print "startup at %d:%02d:%02d" % (time.localtime(start)[3], time.localtime(start)[4],time.localtime(start)[5])

    # this is a single pass check
    # TODO: add cmdline option for daemon mode vs single pass

    #launch_tests(game_list, 1)
    #print "outta launch_tests
    #worker_pool.wait_completion()
    #print "workers done"
    #output_pool.wait_completion()
    #rightnow= time.time()
    #
    # print "quit at %d:%02d:%02d" % (time.localtime(rightnow)[3], time.localtime(rightnow)[4],time.localtime(rightnow)[5])
    #
    #print "Elapsed Time: %s" % (time.time() - start)


## this is a stupid looper.  It waits until the minute has changed (this
## gracefully handles a situation where the checks take more than a minute.

    while True:
        localtime=time.localtime(time.time())
        if localtime[4] != curmin:
            curmin = localtime[4]
            print "launch! %s" % (time.localtime(time.time()),)
            launch_tests(game_list, curmin)
            print "waiting for joins"
            worker_pool.wait_completion()
            print "workers done"
            output_pool.wait_completion()
            print "back %s" % (time.localtime(time.time()),)

        time.sleep(1)

#        check_loop_pool.wait_completion()

    print "Elapsed Time: %s" % (time.time() - start)

