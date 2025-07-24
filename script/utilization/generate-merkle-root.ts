import fs from 'fs'
import { parseBalanceMap } from './parse-balance-map'

const inputFilePath = 'script/utilization/distributions.json'
const outputFilePath = 'script/utilization/merkletree.json'

const json = JSON.parse(fs.readFileSync(inputFilePath, { encoding: 'utf8' }))

if (typeof json !== 'object') throw new Error('Invalid JSON')

const merkleTree = parseBalanceMap(json)

fs.writeFileSync(outputFilePath, JSON.stringify(merkleTree, null, 2))
