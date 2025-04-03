import { Variant } from 'dbus-next';
import {
	MediaPlayer,
	bus,
	getPrimaryPlayer,
	listPlayers,
	setRecentPlayer,
	type PlayerMetadata,
} from './common';

const BAR_LENGTH = 20;

// @ts-expect-error
bus._addMatch(
	"type='signal',sender='org.freedesktop.DBus',interface='org.freedesktop.DBus',path='/org/freedesktop/DBus',member='NameOwnerChanged'",
);

const players = new Map<string, MediaPlayer>();
let dirty = false;

async function addPlayer(name: string) {
	if (players.has(name)) return;
	const player = await MediaPlayer.init(name);
	if (!player) return;
	players.set(name, player);

	player.properties.on(
		'PropertiesChanged',
		async (iface, properties: Record<string, Variant>) => {
			if (iface !== 'org.mpris.MediaPlayer2.Player') return;
			if ('PlaybackStatus' in properties) {
				await setRecentPlayer(name);
			}
			update();
		},
	);
	const status = await player.getPlaybackStatus();
	if (status === 'Playing') {
		await setRecentPlayer(name);
	}
	await update();
}

bus.on('message', async (msg) => {
	if (msg.member !== 'NameOwnerChanged') return;
	const [name, oldOwner, newOwner] = msg.body;
	if (!name.startsWith('org.mpris.MediaPlayer2.')) return;

	if (newOwner === '') {
		players.get(name)?.disconnect();
		players.delete(name);
		await update();
		return;
	}
	if (oldOwner === '') {
		await addPlayer(name);
		return;
	}
});

for (const name of await listPlayers()) {
	await addPlayer(name);
}

async function update() {
	const playerData: Array<{
		name: string;
		title: string;
		metadata: PlayerMetadata;
		current: number;
		duration: number;
		status: 'Playing' | 'Paused' | 'Stopped';
	}> = [];

	for (const [name, player] of players) {
		const metadata = await player.getMetadata();
		const status = await player.getPlaybackStatus();
		if (status === 'Playing') dirty = true;
		const current = await player.getPosition();
		playerData.push({
			name,
			get title() {
				const title = metadata['xesam:title'] ?? '';
				if (title.length > 30) {
					return title.slice(0, 30) + '...';
				}
				return title;
			},
			get duration() {
				return Number((metadata['mpris:length'] ?? 0n) / 1000000n);
			},
			metadata,
			current: Number(current / 1000000n),
			status,
		});
	}
	const primaryPlayer = await getPrimaryPlayer(playerData);
	if (!primaryPlayer) {
		console.log(JSON.stringify({ text: '' }));
	}
	// sort the primary player to the top
	playerData.sort((a, b) => {
		if (a === primaryPlayer) {
			return -1;
		}
		if (b === primaryPlayer) {
			return 1;
		}
		return 0;
	});

	const tooltip = playerData
		.map((player) => {
			let name = player.name.substring('org.mpris.MediaPlayer2.'.length);
			if (name.includes('.')) name = name.substring(0, name.lastIndexOf('.'));
			let t = `${player.status === 'Playing' ? '' : ' '}${
				player.title
			} - ${player.metadata['xesam:artist']?.join(', ')} (${name})`;
			if (player.duration > 0) {
				t += `\n${formatTime(player.current)} ${makeProgressBar(
					player.current,
					player.duration,
				)} ${formatTime(player.duration)}`;
			}
			return t;
		})
		.join('\n\n─────────────────────────────\n\n');

	const pauseIcon = primaryPlayer?.status === 'Playing' ? '' : '';
	console.log(
		JSON.stringify({
			text: `${pauseIcon} ${primaryPlayer?.title ?? 'no player'} `,
			tooltip,
		}),
	);
}

function makeProgressBar(current: number, duration: number) {
	const progress = (current / duration) * BAR_LENGTH;

	return '━'.repeat(progress) + '⏺︎' + '─'.repeat(BAR_LENGTH - progress);
}

setInterval(() => {
	if (dirty) update();
}, 1000);

function formatTime(time: number) {
	const minutes = Math.floor(time / 60);
	const seconds = time % 60;
	return `${minutes}:${seconds < 10 ? '0' : ''}${seconds}`;
}
