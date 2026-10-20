// queries to build the tables in the database
const buildAllTables = {
    main_table: `
        CREATE TABLE main_table(
            subj INT NOT NULL,
            uid CHAR(13),
            pid CHAR(24),
            t_init TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            t_start TIMESTAMP NULL,
            t_ques TIMESTAMP NULL,
            t_end TIMESTAMP NULL,
            comp TEXT,
            pref TEXT,
            seqs TEXT,
            bonus TEXT,
            UNIQUE (pid),
            PRIMARY KEY (uid)
        );
    `,
    task_table: `
        CREATE TABLE task_table(
            uid CHAR(13),
            subj INT,
            data TEXT
            );
    `,
    resp_table: `
        CREATE TABLE resp_table(
            uid CHAR(13),
            subj INT,
            iblk INT,
            iseq_abs INT,
            iseq_blk INT,
            icnd INT,
            it_abs INT,
            it_seq INT, 
            is_guess BOOL, 
            targ_shape BOOL,
            targ_blue BOOL, 
            symm INT,
            shape INT,
            color INT,
            is_left BOOL,
            rt INT,
            ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
    `,
    ques_table: `
        CREATE TABLE ques_table(
            uid CHAR(13),
            subj INT,
            label TEXT,
            responses TEXT,
            ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
    `
};

exports.buildAllTables = buildAllTables;
