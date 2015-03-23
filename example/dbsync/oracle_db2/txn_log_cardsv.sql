drop table txn_log_cardsv;
create table txn_log_cardsv(
    -- 清算日期,  流水号， 原始流水号, 冲正标志, 应答码
    sdate      date,
    ssn        char(6),
    ssn_org    char(6),
    rev_flag   char(1),
    resp_code  char(2),

    -- 交易日期时间
    tdt        char(19),

    -- 受理机构ID, 发送机构ID, 接收机构ID
    acq_id     char(12),
    snd_id     char(12),    
    rcv_id     char(12),

    -- 商户号, 终端号
    mid        char(15),
    tid        char(8),
    psam       char(16),

    -- 检索参考号, 授权号
    refnum     char(12),
    authnum    char(12),

    -- 交易金额
    tamt       bigint,

    -- 卡号
    -- 卡类型
    cno        char(20),
    ctype      char(2),

    -- 最近更新时间
    ts_u       timestamp
);
create unique index idx_txn_log_cardsv on db2_log_cardsv(tdt, ssn);

-----------------------------------------
--              字段说明
-----------------------------------------
--  sdate     : 清算日期
--  ssn       : 流水号
--  ssn_org   : 原交易流水号
--  rev_flag  : 冲正标志
--  resp_code : 应答码
-----------------------------------------
--  tdt       : 交易日期时间
-----------------------------------------
--  acq_id    : 受理机构ID
--  snd_id    : 发送机构ID
--  rcv_id    : 接收机构ID
-----------------------------------------
--  mid       : 商户号
--  tid       : 终端号
--  refnum    : 检索参考号码
--  authnum   : 授权号
--  tamt      : 交易金额
-----------------------------------------
--  cno       : 卡号
--  ctype     : 卡类型
-----------------------------------------

