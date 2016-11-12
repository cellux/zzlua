local appfactory = require('appfactory')

local app = appfactory.OpenGLApp {
   title = "skeleton",
   quit_on_escape = true,
}

app:run()
