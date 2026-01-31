const http = require('http');

const BASE_URL = 'http://InfraS-Panta-ANti8qT1Cybj-1735811194.eu-north-1.elb.amazonaws.com';

async function post(path, data) {
    return new Promise((resolve, reject) => {
        const req = http.request(`${BASE_URL}${path}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' }
        }, (res) => {
            let body = '';
            res.on('data', chunk => body += chunk);
            res.on('end', () => {
                if (res.statusCode >= 200 && res.statusCode < 300) {
                    resolve(JSON.parse(body));
                } else {
                    reject(new Error(`Status ${res.statusCode}: ${body}`));
                }
            });
        });
        req.on('error', reject);
        req.write(JSON.stringify(data));
        req.end();
    });
}

async function seed() {
    console.log("Seeding data...");

    try {
        // 1. Pending Request
        console.log("Creating Pending Request...");
        await post('/api/v1/requests', {
            title: 'Glass Jars & Electronics',
            location: '456 Solar Ave, Eco City',
            scheduledFrom: new Date(Date.now() + 86400000).toISOString(), // Tomorrow
            scheduledTo: new Date(Date.now() + 90000000).toISOString()
        });

        // 2. Accepted Request
        console.log("Creating Accepted Request...");
        const req2 = await post('/api/v1/requests', {
            title: 'Old Cardboard Boxes',
            location: '123 Green St, Eco City',
            scheduledFrom: new Date().toISOString(),
            scheduledTo: new Date(Date.now() + 3600000).toISOString()
        });
        await post('/api/v1/requests/accept', { id: req2.id });

        // 3. Picked Up Request
        console.log("Creating Picked Up Request...");
        const req3 = await post('/api/v1/requests', {
            title: 'Collection of Plastic Bottles',
            location: '123 Green St, Eco City',
            scheduledFrom: new Date(Date.now() - 86400000).toISOString(), // Yesterday
            scheduledTo: new Date(Date.now() - 80000000).toISOString()
        });
        await post('/api/v1/requests/accept', { id: req3.id });
        await post('/api/v1/requests/complete', { id: req3.id });

        console.log("Seed complete!");
    } catch (e) {
        console.error("Seeding failed:", e.message);
    }
}

seed();
