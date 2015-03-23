drop table sync_ctl;
create table sync_ctl (
    stable       char(32)       not null,
    vfld_src     varchar(2048)  not null,
    tfld_src     char(32)       not null,

    dtable       char(32)       not null,
    kfld_dst     varchar(128)   not null,
    vfld_dst     varchar(1024)  not null,
    ufld_dst     varchar(128),
    tfld_dst     char(32)       not null,

    convert      varchar(128),

    interval    int             not null,
    gap         int             not null,
    last        timestamp       not null,

    ts_c  timestamp  default current_timestamp,
    ts_u  timestamp
);
create unique index idx_sync_ctl on sync_ctl(stable);

insert into sync_ctl values(
    -- 源数据库表 
    'src_tbl',
    'u1,u2', 
    'ts_u',

    -- 目的数据库表 
    -- 
    'dst_tbl',
    'k12',  
    'u1,u2,u12',
    'u12', 
    'ts_u',

    -- config
    '/Users/zhouchao/workspace/zeta/example/dbsync/config.pl',
    
    -- interval , gap, last
    3,
    5,
    '1999-01-24 11:06:20.247406',

    -- ts_c ts_u
    '1999-01-24 11:06:20.247406',
    '1999-01-24 11:06:20.247406'
);

