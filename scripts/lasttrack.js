async function lasttrack() {
    try {
        const response = await fetch('https://homelab.joshooaj.com/music/recenttracks?limit=1');
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        const data = await response.json();
        return data;
    } catch (error) {
        console.error('Error fetching recent track name:', error);
    }
}

document.addEventListener('DOMContentLoaded', async function() {
    async function updateLastTrack() {
        var track = await lasttrack();
        document.querySelectorAll('.last-track').forEach(element => {
            element.innerHTML = `<a href="${track.url}">${track.name} - ${track.artist["#text"]}</a>`
        });
    }
    updateLastTrack()
    setInterval(updateLastTrack, 10000)
})