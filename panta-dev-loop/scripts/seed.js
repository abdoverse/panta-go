const http = require('http');
const https = require('https');

const BASE_URL = process.env.API_BASE_URL || process.env.BASE_URL || 'http://localhost:8080';

async function post(urlStr, data = {}) {
    return new Promise((resolve, reject) => {
        const parsed = new URL(urlStr);
        const transport = parsed.protocol === 'https:' ? https : http;
        const payload = JSON.stringify(data);

        const req = transport.request(parsed, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(payload)
            }
        }, (res) => {
            let body = '';
            res.on('data', chunk => body += chunk);
            res.on('end', () => {
                if (res.statusCode >= 200 && res.statusCode < 300) {
                    try {
                        resolve(JSON.parse(body));
                    } catch (_) {
                        resolve(body);
                    }
                } else {
                    reject(new Error(`Status ${res.statusCode}: ${body}`));
                }
            });
        });

        req.on('error', reject);
        req.write(payload);
        req.end();
    });
}

async function seed() {
    console.log(`🌱 Seeding Panta demo data to: ${BASE_URL}...`);
    try {
        const seedResult = await post(`${BASE_URL}/api/v1/demo/seed`);
        console.log(`✅ Demo data seeded successfully! Created ${(seedResult.requests || []).length} sample requests:`);
        for (const req of (seedResult.requests || [])) {
            console.log(`   - [${req.status.toUpperCase()}] ${req.title} (${req.location})`);
        }
    } catch (e) {
        console.error("❌ Seeding failed:", e.message);
        process.exit(1);
    }
}

seed();
