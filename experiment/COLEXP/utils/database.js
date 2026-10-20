const mysql = require('mysql2');

/* Database configuration */
const db_config = () => {
    // get configuration details from CLI environment (env)
    if (process.env.NODE_ENV === 'production') {
        return {
            connectionLimit: 10,
            host: 'YOUR_HOST',
            user: 'YOUR_USER',
            password: 'YOUR_PASSWORD',
            database: 'YOUR_DATABASE',
            port: '36924',
        }
    } else {
        return {
            connectionLimit: 10,
            host: 'YOUR_HOST',
            user: 'YOUR_USER',
            password: 'YOUR_PASSWORD',
            database: 'YOUR_DATABASE',
            port: '3306',
            socketPath: '/tmp/mysql.sock'
        }
    }
};

// test connection to the server (can disable once confirmed)
if (false) {
    const conn = mysql.createConnection(db_config);
    conn.connect(err => {
        if (err) throw err;
        console.log('Connection to MySQL database successful!');
    });
}

// create the SQL pool
const pool = mysql.createPool(db_config());

module.exports = pool.promise();