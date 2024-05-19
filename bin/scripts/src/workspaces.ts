import { $ } from 'bun';
import variables from '../../../home/.chezmoidata.json';
const cmd = process.argv[2];

const monitorMap: Record<string, number[]> = {
	[variables.monitors.right]: [1, 2, 3, 4, 5],
	[variables.monitors.left]: [6, 7, 8, 9, 10],
};

if (cmd === 'switchmonitor' || cmd === 'movemonitor') {
	const monitors: Array<{
		focused: boolean;
		name: string;
		activeWorkspace: { id: number };
	}> = await $`hyprctl -j monitors`.json();

	const current = monitors.find((m) => m.focused);
	if (!current) process.exit(1);
	const other = monitors.find((m) => !m.focused);
	if (!other) process.exit(1);

	if (cmd === 'switchmonitor') {
		await $`hyprctl dispatch workspace ${other.activeWorkspace.id}`;
	} else if (cmd === 'movemonitor') {
		await $`hyprctl dispatch movetoworkspacesilent ${other.activeWorkspace.id}`;
	}
} else if (cmd === 'switch' || cmd === 'move') {
	const num = parseInt(process.argv[3] ?? '');
	if (!cmd || isNaN(num)) process.exit(0);
	const workspace: {
		monitor: string;
	} = await $`hyprctl -j activeworkspace`.json();

	const target = monitorMap[workspace.monitor]?.[num - 1];
	if (!target) process.exit(1);

	if (cmd === 'switch') {
		await $`hyprctl dispatch workspace ${target}`;
	} else if (cmd === 'move') {
		await $`hyprctl dispatch movetoworkspacesilent ${target}`;
	}
} else if (cmd === 'next' || cmd === 'previous') {
	const workspace: {
		monitor: string;
		id: number | string;
	} = await $`hyprctl -j activeworkspace`.json();

	if (typeof workspace.id !== 'number') process.exit(1);

	const monitor = monitorMap[workspace.monitor];
	if (!monitor) process.exit(1);

	const index = monitor.indexOf(workspace.id);
	if (index === undefined || index === -1) process.exit(1);

	const delta = cmd === 'next' ? 1 : -1;
	const nextIndex = (index + delta + monitor.length) % monitor.length;
	await $`hyprctl dispatch workspace ${monitor[nextIndex]}`;
}
