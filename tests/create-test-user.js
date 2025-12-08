#!/usr/bin/env node

/**
 * Create Test User Script
 * Usage: node scripts/create-test-user.js [email] [password] [username]
 * Example: node scripts/create-test-user.js alice@test.com password123 alice
 */

const bcrypt = require('bcrypt');
const { Client } = require('pg');

// Database configuration
const dbConfig = {
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'rtb_database',
  user: process.env.DB_USER || 'postgres'
};

async function createTestUser(email, password, username) {
  const client = new Client(dbConfig);

  try {
    await client.connect();
    console.log('Connected to database');

    // Hash password
    const passwordHash = await bcrypt.hash(password, 12);
    console.log('Password hashed');

    // Generate random member weight (0.5 - 2.0)
    const memberWeight = (Math.random() * 1.5 + 0.5).toFixed(2);

    // Insert user
    const query = `
      INSERT INTO users (email, password_hash, username, member_weight)
      VALUES ($1, $2, $3, $4)
      RETURNING id, email, username, member_weight, created_at
    `;

    const result = await client.query(query, [email, passwordHash, username, memberWeight]);
    const user = result.rows[0];

    console.log('\n✅ User created successfully!');
    console.log('=====================================');
    console.log(`User ID:       ${user.id}`);
    console.log(`Email:         ${user.email}`);
    console.log(`Username:      ${user.username}`);
    console.log(`Password:      ${password}`);
    console.log(`Member Weight: ${user.member_weight}`);
    console.log(`Created At:    ${user.created_at}`);
    console.log('=====================================');
    console.log('\nYou can now login with:');
    console.log(`  Email:    ${user.email}`);
    console.log(`  Password: ${password}`);
    console.log('');

  } catch (error) {
    if (error.code === '23505') {
      console.error('\n❌ Error: Email or username already exists');
      console.error(`Email "${email}" or username "${username}" is already registered`);
    } else {
      console.error('\n❌ Error creating user:', error.message);
    }
    process.exit(1);
  } finally {
    await client.end();
  }
}

// Parse command line arguments
const args = process.argv.slice(2);

if (args.length === 0 || args.includes('-h') || args.includes('--help')) {
  console.log(`
Create Test User Script
========================

Usage: node scripts/create-test-user.js [email] [password] [username]

Arguments:
  email     - User email address
  password  - User password (plain text)
  username  - Username (optional, defaults to email prefix)

Examples:
  node scripts/create-test-user.js alice@test.com password123 alice
  node scripts/create-test-user.js bob@test.com secret123 bob
  node scripts/create-test-user.js carol@test.com test123

Quick Test Users:
  node scripts/create-test-user.js test1@test.com test123 test1
  node scripts/create-test-user.js test2@test.com test123 test2
  node scripts/create-test-user.js test3@test.com test123 test3
`);
  process.exit(0);
}

const email = args[0];
const password = args[1] || 'test123';
const username = args[2] || email.split('@')[0];

// Validate inputs
if (!email || !email.includes('@')) {
  console.error('❌ Error: Invalid email address');
  process.exit(1);
}

if (password.length < 6) {
  console.error('❌ Error: Password must be at least 6 characters');
  process.exit(1);
}

// Create user
createTestUser(email, password, username);
