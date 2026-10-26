









const crypto = require('crypto');
const { query } = require('../config/database');










const generatePayloadHash = (payloadData) => {
  const json = JSON.stringify(payloadData, Object.keys(payloadData).sort());
  return crypto.createHash('sha256').update(json).digest('hex');
};














const generateBlockHash = (index, timestamp, type, payloadHash, prevHash) => {
  const data = `${index}${timestamp}${type}${payloadHash}${prevHash}`;
  return crypto.createHash('sha256').update(data).digest('hex');
};















const addBlock = async (type, refId, payload) => {

  const lastBlockResult = await query(
    'SELECT block_index, hash FROM ledger_blocks ORDER BY block_index DESC LIMIT 1'
  );

  if (lastBlockResult.rows.length === 0) {
    throw new Error('Genesis block tidak ditemukan. Jalankan migrasi SQL terlebih dahulu.');
  }

  const lastBlock = lastBlockResult.rows[0];
  const newIndex = lastBlock.block_index + 1;
  const prevHash = lastBlock.hash;
  const timestamp = new Date().toISOString();


  const payloadHash = generatePayloadHash(payload);


  const blockHash = generateBlockHash(newIndex, timestamp, type, payloadHash, prevHash);


  const result = await query(
    `INSERT INTO ledger_blocks (block_index, block_type, ref_id, payload_hash, prev_hash, hash, created_at)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING *`,
    [newIndex, type, refId, payloadHash, prevHash, blockHash, timestamp]
  );

  return result.rows[0];
};














const verifyChain = async () => {
  const result = await query(
    'SELECT * FROM ledger_blocks ORDER BY block_index ASC'
  );

  const blocks = result.rows;

  if (blocks.length === 0) {
    return { valid: false, message: 'Tidak ada blok dalam ledger.' };
  }


  const genesis = blocks[0];
  if (genesis.block_index !== 0 || genesis.block_type !== 'GENESIS') {
    return {
      valid: false,
      message: 'Genesis block tidak valid.',
      invalid_block: genesis,
    };
  }


  for (let i = 1; i < blocks.length; i++) {
    const block = blocks[i];
    const prevBlock = blocks[i - 1];


    if (block.prev_hash !== prevBlock.hash) {
      return {
        valid: false,
        message: `Rantai rusak pada blok ke-${block.block_index}. prev_hash tidak cocok.`,
        invalid_block: {
          block_index: block.block_index,
          block_type: block.block_type,
          ref_id: block.ref_id,
          created_at: block.created_at,
          stored_hash: block.hash,
          expected_prev_hash: prevBlock.hash,
          actual_prev_hash: block.prev_hash,
        },
      };
    }


    const recalculatedHash = generateBlockHash(
      block.block_index,
      block.created_at instanceof Date
        ? block.created_at.toISOString()
        : new Date(block.created_at).toISOString(),
      block.block_type,
      block.payload_hash,
      block.prev_hash
    );


    if (block.hash !== recalculatedHash) {
      return {
        valid: false,
        message: `Blok ke-${block.block_index} telah dimodifikasi! Hash tidak cocok.`,
        invalid_block: {
          block_index: block.block_index,
          block_type: block.block_type,
          ref_id: block.ref_id,
          created_at: block.created_at,
          stored_hash: block.hash,
          recalculated_hash: recalculatedHash,
        },
      };
    }
  }

  return {
    valid: true,
    message: `Semua ${blocks.length} blok valid. Rantai utuh.`,
    total_blocks: blocks.length,
  };
};

module.exports = { addBlock, verifyChain, generatePayloadHash, generateBlockHash };
