#include <string>
#include <vector>
#include <map>
#include <set>
#include <memory>
#include <fstream>

#include <stdio.h>
#include <unistd.h>
#include <signal.h>
#include <pthread.h>
#include <dirent.h>
#include <sys/stat.h>

#include <zmq.hpp>
#include <jack/jack.h>

/*** various helpers ***/

#define LOG(...) do {                                               \
    fprintf(stdout, __VA_ARGS__);                                   \
    fprintf(stdout, "\n");                                          \
  } while(0)

#define DIE(...) do {                                               \
    fprintf(stderr, "Error in %s line #%d:\n", __FILE__, __LINE__); \
    LOG(__VA_ARGS__);                                               \
    exit(1);                                                        \
  } while(0)

#define CHECK(expr, ...) if (!(expr)) DIE(__VA_ARGS__)

/*** messages ***/

enum showtime_msg_type {
  /* signals */
  SHOWTIME_SIGNAL_RECEIVED,
  /* jack */
  SHOWTIME_JACK_PORT_REGISTRATION,
  SHOWTIME_JACK_CLIENT_REGISTRATION
};

#define SHOWTIME_MAX_CLIENT_NAME_LENGTH 128

struct showtime_msg_t {
  showtime_msg_type type;
  /* signals */
  int signum;
  int pid;
  /* jack */
  jack_port_id_t port;
  int reg;
  char name[SHOWTIME_MAX_CLIENT_NAME_LENGTH+1];
};

class Patch {
public:
  Patch(const char *path)
    : path_(path)
  {
    reload();
  }

  void reload() {
    connections_.clear();
    std::ifstream in(path_);
    if (! in.good()) {
      DIE("cannot open patch file: %s", path_);
    }
    std::string src;
    std::string dst;
    State st = START;
    while (in) {
      std::string item = parse_word(in);
      if (item.empty()) {
        break; // eof
      }
      int colon_pos = item.find(':');
      if (colon_pos != std::string::npos) {
        if (st == START) {
          src = item;
          st = LHS_ASSIGNED;
        }
        else if (st == RIGHT_ARROW) {
          dst = item;
          st = RHS_ASSIGNED;
        }
        else if (st == LEFT_ARROW) {
          dst = src;
          src = item;
          st = RHS_ASSIGNED;
        }
      }
      else if (item == "->") {
        st = RIGHT_ARROW;
      }
      else if (item == "<-") {
        st = LEFT_ARROW;
      }
      else {
        DIE("parse error");
      }
      if (st == RHS_ASSIGNED) {
        LOG("parsed connection: %s -> %s", src.c_str(), dst.c_str());
        connections_.push_back(ConnectionDescriptor(src, dst));
        st = START;
      }
    }
  }

private:
  std::string parse_word(std::ifstream &s) {
    std::string word;
    char ch;
    // skip initial whitespace
    while (!s.eof()) {
      ch = s.get();
      if (!isspace(ch))
        break;
    }
    if (s.eof()) {
      // reached eof, return empty string
      return word;
    }
    // add first non-ws char to result
    word += ch;
    // read rest of word
    while (!s.eof()) {
      ch = s.get();
      if (isspace(ch))
        break;
      word += ch;
    }
    return word;
  }

  typedef std::pair<std::string, std::string> ConnectionDescriptor;
  typedef std::vector<ConnectionDescriptor> ConnectionDescriptorVec;
  const char *path_;
  enum State {
    START,
    LHS_ASSIGNED,
    RIGHT_ARROW,
    LEFT_ARROW,
    RHS_ASSIGNED
  };
  ConnectionDescriptorVec connections_;
};

class JackConnection {
public:
  JackConnection(zmq::context_t &zmq_ctx, const std::string &jack_client_name)
    : zmq_ctx_(zmq_ctx),
      client_socket_(0) // must be created in the jack thread
  {
    jack_options_t jack_options = (jack_options_t) (JackNoStartServer | JackUseExactName);
    jack_client_ = jack_client_open(jack_client_name.c_str(), jack_options, 0);
    CHECK(jack_client_, "jack_client_open() failed");
    LOG("connected to jackd with client name=[%s]", jack_client_name.c_str());
    if (jack_set_thread_init_callback(jack_client_,
                                      jack_thread_init_callback,
                                      this))
      DIE("jack_set_thread_init_callback() failed");
    if (jack_set_client_registration_callback(jack_client_,
                                              jack_client_registration_callback,
                                              this))
      DIE("jack_set_client_registration_callback() failed");
    if (jack_set_port_registration_callback(jack_client_,
                                            jack_port_registration_callback,
                                            this))
      DIE("jack_set_port_registration_callback() failed");
    start();
  }

  ~JackConnection() {
    stop();
    jack_client_close(jack_client_);
    LOG("disconnected from jackd");
    /* the 0MQ socket should be closed in the jack thread, but I don't
       know how to do that */
    if (client_socket_) {
      delete client_socket_;
      client_socket_ = 0;
    }
  }

  jack_port_t *get_port_by_id(jack_port_id_t port) {
    return jack_port_by_id(jack_client_, port);
  }

private:
  void start() {
    if (jack_activate(jack_client_))
      DIE("jack_activate() failed");
  }

  void stop() {
    if (jack_deactivate(jack_client_))
      DIE("jack_deactivate() failed");
  }

  static void jack_thread_init_callback(void *arg) {
    JackConnection *jc = (JackConnection*) arg;
    /* this callback gets called in two different threads - I don't know
       why - so we must be careful to avoid double initialization of the
       client socket */
    if (jc->client_socket_ == 0) {
      jc->client_socket_ = new zmq::socket_t(jc->zmq_ctx_, ZMQ_PUB);
      jc->client_socket_->connect("inproc://messages");
    }
  }

  static void jack_port_registration_callback(jack_port_id_t port,
                                              int reg,
                                              void *arg) {
    JackConnection *jc = (JackConnection*) arg;
    showtime_msg_t msg;
    msg.type = SHOWTIME_JACK_PORT_REGISTRATION;
    msg.port = port;
    msg.reg = reg;
    if (jc->client_socket_->send(&msg, sizeof(msg)) != sizeof(msg))
      DIE("error while sending jack event message from port registration callback");
  }

  static void jack_client_registration_callback(const char *name,
                                                int reg,
                                                void *arg) {
    JackConnection *jc = (JackConnection*) arg;
    showtime_msg_t msg;
    msg.type = SHOWTIME_JACK_CLIENT_REGISTRATION;
    if (strlen(name) > SHOWTIME_MAX_CLIENT_NAME_LENGTH)
      DIE("jack client registration callback: client name too long");
    strcpy(msg.name, name);
    msg.reg = reg;
    if (jc->client_socket_->send(&msg, sizeof(msg)) != sizeof(msg))
      DIE("error while sending jack event message from client registration callback");
  }

private:
  zmq::context_t& zmq_ctx_;
  zmq::socket_t *client_socket_;
  jack_client_t *jack_client_;
};

class SignalManager {
public:
  SignalManager(zmq::context_t &zmq_ctx) 
    : zmq_ctx_(zmq_ctx)
  {
    sigset_t ss;
    sigfillset(&ss);
    /* block all signals in main thread */
    if (pthread_sigmask(SIG_BLOCK, &ss, &saved_sigset_) != 0) {
      DIE("pthread_sigmask() failed\n");
    }
    /* signals are handled in a dedicated thread which sends a 0MQ
       message to the main thread when a signal arrives */
    if (pthread_create(&signal_handler_thread_,
                       NULL,
                       signal_handler_thread,
                       this) != 0) {
      DIE("cannot create signal handler thread: pthread_create() failed\n");
    }
  }

  ~SignalManager() {
    if (pthread_join(signal_handler_thread_, NULL))
      DIE("pthread_join() failed for signal handler thread");
    /* restore signal mask */
    if (pthread_sigmask(SIG_SETMASK, &saved_sigset_, NULL) != 0)
      DIE("cannot restore signal mask: pthread_sigmask() failed");
  }

private:
  static void *signal_handler_thread(void *arg) {
    SignalManager *sm = (SignalManager*) arg;
    sigset_t ss;
    siginfo_t siginfo;
    sigfillset(&ss);
    showtime_msg_t msg;
    int signum;
    zmq::socket_t sock(sm->zmq_ctx_, ZMQ_PUB);
    sock.connect("inproc://messages");
    for (;;) {
      signum = sigwaitinfo(&ss, &siginfo);
      if (signum < 0) {
        DIE("sigwait() failed\n");
      }
      msg.type = SHOWTIME_SIGNAL_RECEIVED;
      msg.signum = signum;
      msg.pid = siginfo.si_pid;
      if (sock.send(&msg, sizeof(msg)) != sizeof(msg))
        DIE("zmq_send() failed in signal handler thread");
      if (signum == SIGTERM || signum == SIGINT) break;
    }
  }

private:
  zmq::context_t &zmq_ctx_;
  pthread_t signal_handler_thread_;
  sigset_t saved_sigset_;
};

class Child {
public:
  Child(const std::string &prefix, const std::string &name)
    : prefix_(prefix),
      name_(name),
      pid_(0)
  {}

  bool valid() {
    std::string run_path = name_+"/run";
    return access(run_path.c_str(), X_OK) == 0;
  }

  bool running() {
    return pid_ ? kill(pid_,0)==0 : false;
  }

  void start() {
    LOG("starting child: %s", name_.c_str());
    pid_t pid = fork();
    if (pid==0) {
      // child
      std::string fullname = prefix_+"."+name_;
      CHECK(chdir(name_.c_str())==0, "chdir() to child root failed: %s", name_.c_str());
      execl("./run", name_.c_str(), fullname.c_str(), 0);
      DIE("execl() failed");
    }
    // parent
    pid_ = pid;
  }

  void stop() {
    if (pid_) {
      LOG("killing child: %s", name_.c_str());
      kill(pid_, SIGTERM);
    }
  }

  pid_t pid() { return pid_; }
  void clear_pid() { pid_ = 0; }

private:
  std::string prefix_;
  std::string name_;
  pid_t pid_;
};

class ChildManager {
public:
  ChildManager(const std::string &prefix)
    : prefix_(prefix)
  {}

  bool child_exists(std::string &name) {
    return children_.find(name) != children_.end();
  }

  void add_child(std::string name) {
    children_.insert(ChildMap::value_type(name, Child(prefix_, name)));
  }

  void remove_child(std::string name) {
    children_.erase(name);
  }

  void discover_children() {
    struct stat st;
    int rv;
    struct dirent *entry;
    DIR *dir;

    dir = opendir(".");
    CHECK(dir, "opendir() failed");
    while (entry = readdir(dir)) {
      if (strcmp(entry->d_name, ".")==0 ||
          strcmp(entry->d_name, "..")==0)
        continue;
      rv = stat(entry->d_name, &st);
      CHECK(rv==0, "stat() failed on %s", entry->d_name);
      if (S_ISDIR(st.st_mode)) {
        std::string name(entry->d_name);
        std::string run_path = name+"/run";
        if (access(run_path.c_str(), X_OK) == 0) {
          if (! child_exists(name)) {
            add_child(name);
          }
        }
      }
    }
    closedir(dir);
  }

  void start_children() {
    for (ChildMap::iterator i=children_.begin();
         i!=children_.end();
         i++) {
      Child &c = i->second;
      if (! c.running()) {
        c.start();
      }
    }
  }

  void stop_children() {
    for (ChildMap::iterator i=children_.begin();
         i!=children_.end();
         i++) {
      Child &c = i->second;
      if (c.running()) {
        c.stop();
      }
    }
  }

  void stop_invalid_children() {
    for (ChildMap::iterator i=children_.begin();
         i!=children_.end();
         i++) {
      Child &c = i->second;
      if (!c.valid()) {
        c.stop();
        children_.erase(i);
      }
    }
  }

  void sigchld(int pid) {
    for (ChildMap::iterator i=children_.begin();
         i!=children_.end();
         i++) {
      Child &c = i->second;
      if (c.pid()==pid) {
        c.clear_pid();
        break;
      }
    }
  }

private:
  typedef std::map<std::string, Child> ChildMap;
  ChildMap children_;
  std::string prefix_;
};

class Options {
public:
  Options(int argc, char **argv) {
    int i=1;
    while (i<argc) {
      client_name_ = argv[i];
      i++;
    }
  }
  const std::string &client_name() {
    return client_name_;
  }

private:
  std::string client_name_;
};

class ShowTime {
public:
  ShowTime(int argc, char **argv)
    : /* Options */ opt_(argc, argv),
      /* zmq::context_t */ zmq_ctx_(),
      /* zmq::socket_t */ sub_sock_(zmq_ctx_, ZMQ_SUB),
      /* SignalManager */ sm_(zmq_ctx_),
      /* JackConnection */ jc_(zmq_ctx_, opt_.client_name()),
      /* ChildManager */ cm_(opt_.client_name()),
      /* Patch */ patch_("patch")
  {
  }

  void run() {
    sub_sock_.bind("inproc://messages");
    sub_sock_.setsockopt(ZMQ_SUBSCRIBE, 0, 0);
    cm_.discover_children();
    cm_.start_children();
    zmq::pollitem_t poll_item = { (void*) sub_sock_, 0, ZMQ_POLLIN, 0 };
    showtime_msg_t msg;
    bool running = true;
    while (running) {
      int nevents = zmq::poll(&poll_item, 1, -1);
      if (nevents == 0)
        continue;
      if (sub_sock_.recv(&msg, sizeof(msg)) != sizeof(msg))
        DIE("zmq_recv() failed in main thread when receiving message");
      switch (msg.type) {
      case SHOWTIME_SIGNAL_RECEIVED: {
        LOG("got signal #%d: %s", msg.signum, strsignal(msg.signum));
        if (msg.signum == SIGCHLD) {
          cm_.sigchld(msg.pid);
        }
        if (msg.signum == SIGTERM || msg.signum == SIGINT) {
          running = false;
        }
        break;
      }
      case SHOWTIME_JACK_PORT_REGISTRATION: {
        jack_port_t *port = jc_.get_port_by_id(msg.port);
        if (msg.reg) {
          const char *port_name = jack_port_name(port);
          LOG("registered jack port: %s", port_name);
        }
        else {
          LOG("unregistered jack port: %s", jack_port_name(port));
        }
        break;
      }
      case SHOWTIME_JACK_CLIENT_REGISTRATION: {
        if (msg.reg) {
          LOG("registered jack client: %s", msg.name);
        }
        else {
          LOG("unregistered jack client: %s", msg.name);
        }
        break;
      }
      default:
        DIE("unknown msg.type in received message: %d", msg.type);
      }
    }
    cm_.stop_children();
  }

private:
  Options opt_;
  zmq::context_t zmq_ctx_;
  zmq::socket_t sub_sock_;
  SignalManager sm_;
  JackConnection jc_;
  ChildManager cm_;
  Patch patch_;
};

static void showUsage() {
  printf("Usage: showtime <client-name>\n");
}

int main(int argc, char **argv) {
  if (argc < 2) {
    showUsage();
  }
  else {
    std::auto_ptr<ShowTime> st(new ShowTime(argc, argv));
    st->run();
  }
  return 0;
}
