" Author:
"   Original: Bartek Chaber<czaber@gmail.com>
" Version: 0.01
"
" Requirements: Linux(not tested on Windows), Pyramid
" Description: {{{
"	Use vim commands to run Pyramid commands
"
"	Default Pyramid project looks like this:
"
"	MyProject/
"		myproject/
"		myproject.egg-info/
"		data/
"		docs/
"		developement.ini
"		MANIFEST.in
"		README.txt
"		setup.cfg
"		setup.py
"		test.ini
"	
"	Now, what is what?
"	g:PyramidProjectDir = path/to/MyProject/
"	g:PyramidProjectName = myproject/
"	
"	To start using this plugin you have to 'open' Pylon project with:
"		:PyramidOpen path/to/MyProject/myproject/
"	if everything goes well you should see:
"		Project set: /absolute/path/to/MyProject/myproject
"
"	Now you can use following functions:
"	PyramidOpen <dir> : open another project, current (if any) will be lost
"	PyramidServer [start|stop|restart] : start, stop, restart paster server
"	PyramidCreate [project|controller|template]:
"		project : Create new project TODO: not implemented yet
"		controller : Create new controler. It will as you for name.
"		template : Create new template. It will as you for name.
"		Note: you can use:
"			PyramidCreate template
"			'Template: path/to/template.mako'
"			['Template: path/to/template will' work the same]
"		This will create template.mako in
"				/absolute/path/to/MyProject/myproject/tempates/path/to/
"	PyramidPreview : this will open localhost:5000 with default browser (set in g:PyramidBrowser) 
" 
" Notes:
" I know that code can be buggy. It's my first vim-script, so XXX USE ON OWN RISK XXX.
" }}}

if !exists("g:PyramidProjectName")
	let g:PyramidProjectDir = ""
endif

if !exists("g:PyramidProjectName")
	let g:PyramidProjectName = ""
endif

if !exists("g:PyramidPID")
	let g:PyramidPID = "paster.pid"
endif

if !exists("g:PyramidIniFile")
	let g:PyramidIniFile = "development.ini"
endif

if !exists("g:PyramidBrowser")
	let g:PyramidBrowser = "/usr/bin/open"
endif

if !exists("g:PyramidHost")
	let g:PyramidHost = "localhost"
endif

if !exists("g:PyramidPort")
	let g:PyramidPort = "6543"
endif

"
" Bindings
"

command! -nargs=1 -bar -complete=dir PyramidOpen call g:PyramidOpenProject('<args>')
command! -nargs=1 -bar -complete=customlist,CompleteServer PyramidServer call g:PyramidServer('<args>')
command! -nargs=1 -bar -complete=customlist,CompleteCreate PyramidCreate call g:PyramidCreate('<args>')
command! -nargs=0 -bar PyramidPreview call g:PyramidPreview()

"
" Helpers
"

function! s:PyramidRun(cmd)
	if s:isInvalidPyramidProjectDir(g:PyramidProjectDir)
		return 0
	else
		let s:current = getcwd()
		silent execute "cd ".g:PyramidProjectDir
		execute "!".a:cmd
		silent execute "cd ".s:current
	endif
	return 1
endfunction


function! s:absolutePath(path)
	" absolute
	if match(a:path,"/") == 0
		return a:path
	else
		return getcwd()."/".a:path
	endif
endfunction

function! s:isInvalidDir(dir)
	if isdirectory(a:dir)
		return 0
	else
		return 1
	endif
endfunction

function! s:isNotProjectDir(dir)
	if filereadable(a:dir.g:PyramidIniFile)
		return 0
	endif
	return 1
endfunction

function! s:isNotProjectName(dir,name)
	if isdirectory(a:dir.a:name."/templates")
		return 0
	endif
	if isdirectory(a:dir.a:name."/controllers")
		return 0
	endif
	if isdirectory(a:dir.a:name."/public")
		return 0
	endif
	if isdirectory(a:dir.a:name."/lib")
		return 0
	endif
	if isdirectory(a:dir.a:name."/model")
		return 0
	endif
	return 1
endfunction

function! s:isInvalidPyramidProjectDir(dir)
	if a:dir == ""
		echo "Project directory not set! Use :PyramidOpen"
		return 1
	endif

	if s:isInvalidDir(a:dir)
		echo a:dir.': directory not found'
		return 1
	endif

	if s:isNotProjectDir(a:dir)
		echo 'No Pyramid project in '.a:dir
		return 1
	endif
	return 0
endfunction

"
" OpenProject
"

function! g:PyramidOpenProject(p_dir)
	let p_dir = a:p_dir
	let last_slash = strridx(p_dir, "/") + 1
	let len = strlen(p_dir)

	" remove '/' at end
	if last_slash == len
		let p_dir = strpart(p_dir, 0, len - 1)
		let last_slash = strridx(p_dir, "/") + 1
	endif

	let projectDir  = strpart(p_dir, 0, last_slash)
	let projectName = strpart(p_dir, last_slash)

	if projectDir == ""
		let projectDir = "./"
	endif

	if s:isInvalidPyramidProjectDir(projectDir)
		return 0
	endif

	if s:isNotProjectName(projectDir, projectName)
		echo 'No project named '.projectName.' in '.projectDir
		return 0
	endif

	let g:PyramidProjectDir = s:absolutePath(projectDir)
	let g:PyramidProjectName = projectName
	echo "Project set: ".g:PyramidProjectDir.g:PyramidProjectName
	silent execute "cd ".g:PyramidProjectDir.g:PyramidProjectName
	return 1
endfunction

"
" Server managing
"

function! CompleteServer(ArgLead, CmdLine, CursorPos)
  return ['start', 'stop', 'restart']
endfunction

function! g:PyramidServerStarted()
	if s:isInvalidPyramidProjectDir(g:PyramidProjectDir)
		return -1
	else
		return filereadable(g:PyramidProjectDir.g:PyramidPID)
	endif
endfunction

function! g:PyramidServer(action)
	if a:action == "start"
		call g:PyramidServerStart()
	elseif a:action == "stop"
		call g:PyramidServerStop()
	elseif a:action == "restart"
		call g:PyramidServerRestart()
	endif
endfunction

function! g:PyramidServerStart()
	if g:PyramidServerStarted()
		call g:PyramidServerRestart()
	else
		let cmd = "paster serve --daemon --pid-file=".g:PyramidPID." ".g:PyramidIniFile." start"
		call s:PyramidRun(cmd)
	endif
endfunction

function! g:PyramidServerStop()
	if g:PyramidServerStarted()
		let cmd = "paster serve --daemon ".g:PyramidIniFile." stop"
		call s:PyramidRun(cmd)
		let g:PyramidServerStarted = 0
	else
		echo "Server not started"
	endif
endfunction

function! g:PyramidServerRestart()
	if g:PyramidServerStarted()
		let cmd = "paster serve --daemon ".g:PyramidIniFile." restart"
		call s:PyramidRun(cmd)
	else
		call g:PyramidServerStart()
	endif
endfunction

"
" Creating
"

function! CompleteCreate(ArgLead, CmdLine, CursorPos)
  return ['project', 'controller', 'template']
endfunction

function! g:PyramidCreate(type)
	if a:type == "project"
		call g:PyramidCreateProject()
	elseif a:type == "controller"
		call g:PyramidCreateController()
	elseif a:type == "template"
		call g:PyramidCreateTemplate()
	endif
endfunction

" TODO
function! g:PyramidCreateProject()
	throw "Function Unimplemented"
"	let name = input("Project's name: ")
"	let cmd = "paster create -t pylons ".name
"	let g:PyramidProjectName = name
"	call s:PyramidRun(cmd)
endfunction

function! g:PyramidCreateController()
	let name = input("Controller's name: ")
	let cmd = "paster controller ".name
	call s:PyramidRun(s:cmd)
endfunction

function! g:PyramidCreateTemplate()
	let name = input("Template: ")
	if match(name,".mako$") == -1
		let name = name.".mako"
	endif
	let cmd = "touch ".g:PyramidProjectDir.g:PyramidProjectName."/templates/".name
	if s:PyramidRun(cmd)
		echo "Template \'".g:PyramidProjectDir.g:PyramidProjectName."/templates/".name." created"
	endif
endfunction

" Preview in Browser
function! g:PyramidPreview()
	"let cmd = g:PyramidBrowser." ".g:PyramidHost.":".g:PyramidPort
    let cmd = "/usr/bin/open http://localhost:6543"
	call s:PyramidRun(cmd)
endfunction