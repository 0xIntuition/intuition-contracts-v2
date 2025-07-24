const fs = require('fs');

/*
* Utilization attempts to accomplish 2 things:
*   `Mechanic 1` is meant to ensure people are using their TRUST to create data.
*    --> Criteria 1: TRUST used to create atoms or triples
*    --> Criteria 2: TRUST staked to atoms or triples
*   `Mechanic 2` is to incentivize people to create relevant data.
*   --> Criteria 3: TRUST received as fees for activities on their atoms and triples
*/
const numberOfMechanics = 2
const mechanicPercentages = [40, 60] // % per mechanic
const weightsForCriteria = [1, 2, 3] // weights for criteria
const criteriaForMechanic = [[0, 1], [2]] // criteria for each mechanic
const totalEnergy = [6000, 5000, 2500] // total trust for each criterion
const trustPerEpoch = 1000
const penalty = 50 // % penalty for not claiming trust
const outputFilePath = 'script/utilization/distributions.json'

// TODO: read from database
function getEnergyForUsers() {
  return {
    '0xF3c6F5F265F503f53EAD8aae90FC257A5aa49AC1': [ // wallet address
      [1000, 2000, 500], // [trust used, trust staked, trust received from fees]
      500, // total trust not claimed
    ],
    '0xB9CcDD7Bedb7157798e10Ff06C7F10e0F37C6BdD': [
      [5000, 3000, 2000],
      1000,
    ]
  }
}

// TODO: read from database or from the Delegation contract
function getDelegationsForUsers() {
  return {
    '0xF3c6F5F265F503f53EAD8aae90FC257A5aa49AC1': [
      [
        '0xB9CcDD7Bedb7157798e10Ff06C7F10e0F37C6BdD', // delegated to
        [1000, 500, 0], // delegated trust created, delegated trust staked, delegated trust received from fees
        50, // delegation split %
      ],
    ]
  }
}

// Calculate the distributions for each user based on their trust and criteria
function calculateDistributions(userData) {
  let distributions = {}

  console.log(`Total trust per epoch: ${trustPerEpoch}`)

  const users = Object.keys(userData)
  for (const user of users) {
    // array of [trust used, trust staked, trust received from fees]
    const trust = userData[user][0]

    // total trust not claimed from previous distributions
    const trustNotClaimed = userData[user][1]

    distributions[user] = { 
      total: 0,
      mechanics: [],
    }

    console.log('--------------------------------')
    console.log(`Calculating distributions for ${user}`)
    console.log(`Trust not claimed: ${trustNotClaimed}`)

    for (let i = 0; i < numberOfMechanics; i++) {
      // trust that will be distributed to the mechanic
      // it's a percentage of the total trust per epoch
      const trustForMechanic = (trustPerEpoch * mechanicPercentages[i]) / 100

      console.log(`Trust for mechanic ${i}: ${trustForMechanic} (${mechanicPercentages[i]}% of ${trustPerEpoch})`)

      let weight = 0
      let totalWeightedEnergy = 0
      let userWeightedEnergy = 0

      for (const criteria of criteriaForMechanic[i]) {
        // weight for the criteria
        weight = weightsForCriteria[criteria]

        // total weighted trust for the mechanic
        totalWeightedEnergy += totalEnergy[criteria] * weight;

        // weighted trust for the user
        userWeightedEnergy += trust[criteria] * weight;

        console.log(`Criteria: ${criteria}`)
        console.log(`Trust total: ${totalEnergy[criteria]}`)
        console.log(`Trust user: ${trust[criteria]}`)
        console.log(`Weight: ${weight}`)
        console.log(`Total weighted trust: ${totalWeightedEnergy}`)
        console.log(`User weighted trust: ${userWeightedEnergy}`)
      }

      // trust for the user for the mechanic
      const userTrustForMechanic = (totalWeightedEnergy == 0) ? 0 : (trustForMechanic * userWeightedEnergy) / totalWeightedEnergy

      console.log(`User trust for mechanic ${i}: ${userTrustForMechanic}`)

      distributions[user].mechanics[i] = userTrustForMechanic
      distributions[user].total += userTrustForMechanic

      console.log(`User total updated: ${distributions[user].total}`)
      console.log('--------------------------------')
    }

    // add the trust not claimed from previous distributions, with a penalty
    distributions[user].total += trustNotClaimed * (100 - penalty) / 100

    console.log(`Trust not claimed with penalty: ${trustNotClaimed * (100 - penalty) / 100  }`)
    console.log(`User total with penalty: ${distributions[user].total}`)
    console.log('--------------------------------')
  }

  return distributions
}

// Adjust the distributions by the delegations
function adjustDistributionsByDelegations(userData, distributions) {
  const delegations = getDelegationsForUsers()

  console.log(delegations)

  const users = Object.keys(delegations)
  for (const user of users) {

    console.log('--------------------------------')
    console.log(`Calculating delegations for ${user}`)

    for (const delegation of delegations[user]) {
      const [delegatedTo, delegatedEnergy, delegationSplit] = delegation

      console.log(`Delegated to: ${delegatedTo}`)
      console.log(`Delegated trust: ${delegatedEnergy}`)

      // trust of the delegate
      const trust = userData[delegatedTo][0]

      for (let i = 0; i < numberOfMechanics; i++) {
        const userTrustForMechanic = distributions[delegatedTo].mechanics[i]

        console.log(`User trust for mechanic ${i}: ${userTrustForMechanic}`)

        let weight = 0
        let totalEnergy = 0
        let userEnergy = 0

        for (const criteria of criteriaForMechanic[i]) { 
          // weight for the criteria
          weight = weightsForCriteria[criteria]

          // The delegate reward is proportional to the TRUST delegated vs its own TRUST
          totalEnergy += trust[criteria] * weight
          userEnergy += delegatedEnergy[criteria] * weight

          console.log(`Criteria: ${criteria}`)
          console.log(`Trust total: ${totalEnergy}`)
          console.log(`Trust delegated: ${userEnergy}`)
          console.log(`Weight: ${weight}`)
        }

        // proportional trust for the user from the delegate for the mechanic
        const userTrustFromDelegateForMechanic = (totalEnergy == 0) ? 0 : (userTrustForMechanic * userEnergy) / totalEnergy
        
        const trustFromDelegate = delegationSplit * userTrustFromDelegateForMechanic / 100

        console.log(`User trust from delegate for mechanic ${i}: ${userTrustFromDelegateForMechanic}`)
        console.log(`Trust from delegate: ${trustFromDelegate} (${delegationSplit}% of ${userTrustFromDelegateForMechanic})`)

        // add the proportional trust to the delegator's trust
        distributions[user].mechanics[i] += trustFromDelegate
        distributions[user].total += trustFromDelegate

        console.log(`User total updated: ${distributions[user].total}`)

        // decrease the proportional trust from the delegate's trust
        distributions[delegatedTo].mechanics[i] -= trustFromDelegate
        distributions[delegatedTo].total -= trustFromDelegate

        console.log(`Delegate total updated: ${distributions[delegatedTo].total}`)
        console.log('--------------------------------')
      }
    }
  }
  return distributions
}

// Generate the distribution file with addresses and their distributions
function generateDistributionFile(distributions) {
  let output = {}
  for (const user of Object.keys(distributions)) {
    output[user] = distributions[user].total  
    console.log(`${user}: ${output[user]}`)
  }
  fs.writeFileSync(outputFilePath, JSON.stringify(output, null, 2))
  console.log(`Distribution file generated at ${outputFilePath}`)
}

// Check if the mechanic percentages sum to 100
function checkMechanicPercentages(mechanicPercentages) {
  // check if the mechanic percentages sum to 100
  const sum = mechanicPercentages.reduce((acc, curr) => acc + curr, 0)
  if (sum !== 100) {
    throw new Error('Mechanic percentages must sum to 100')
  }
}

// Main function to execute the script
async function main() {
  try {
    // Get the trust data for the users
    const userData = getEnergyForUsers()

    console.log(userData)

    // Check mechanic percentages: should sum to 100
    checkMechanicPercentages(mechanicPercentages)

    // Calculate the distribution for each user
    const distributions = calculateDistributions(userData)

    console.log(distributions)

    // Adjust the distributions by the delegations
    const distributionsWithDelegations = adjustDistributionsByDelegations(userData, distributions)

    console.log(distributionsWithDelegations)

    // Generate the distribution file with addresses and their distributions
    generateDistributionFile(distributionsWithDelegations)
  }
  catch (error) {
    console.error(error)
    // eslint-disable-next-line no-process-exit
    process.exit(1)
  }
}

main()
  // eslint-disable-next-line no-process-exit
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    // eslint-disable-next-line no-process-exit
    process.exit(1)
  })
