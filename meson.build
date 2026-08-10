project('vamposer', 'vala', 'c', version: '0.7.4', meson_version: '>=1.1.0')

subdir('src')

if host_machine.system() != 'windows'
	install_data(
		'completions/vamposer.bash',
		install_dir: join_paths(get_option('datadir'), 'bash-completion', 'completions'),
		rename: 'vamposer',
	)

	install_data(
		'completions/_vamposer',
		install_dir: join_paths(get_option('datadir'), 'zsh', 'site-functions'),
	)
endif

if get_option('build_tests')
	subdir('tests')
endif
