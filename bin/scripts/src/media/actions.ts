import { MediaPlayer, bus, getPrimaryPlayer, listPlayers } from './common';

const action = process.argv[2];

const playerData: Array<{
	name: string;
	status: 'Playing' | 'Paused' | 'Stopped';
	player: MediaPlayer;
}> = [];

for (const name of await listPlayers()) {
	const player = await MediaPlayer.init(name);
	if (!player) continue;
	const status = await player.getPlaybackStatus();
	playerData.push({
		name,
		status,
		player,
	});
}

const primaryPlayer = await getPrimaryPlayer(playerData);
if (!primaryPlayer) process.exit(0);

switch (action) {
	case 'playpause':
		if (primaryPlayer.status === 'Playing') {
			await primaryPlayer.player.pause();
		} else {
			await primaryPlayer.player.play();
		}
		break;
	case 'next':
		await primaryPlayer.player.next();
		break;
	case 'previous':
		await primaryPlayer.player.previous();
		break;
}

bus.disconnect();
