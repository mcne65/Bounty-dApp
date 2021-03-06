const { BN, toWei } = web3.utils;

// bdAv1 = Bounty dApp v1
const bdAv1 = artifacts.require("bountydAppv1");

const truffleAssert = require('truffle-assertions');

const amount = new BN(toWei("0.001")); // <-- Change the amount value here for testing
const deadline = new BN(0); // <-- Change the deadline value here for testing
const description = "Please do X for Y Ethers";  // <-- Change the description here for testing
const solution = "X is done";  // <-- Change the solution here for testing
const comment = "X was not done correctly" // <-- Change the comment for testing
const oneEtherInWei = new BN(toWei("1"));
const zeroInBN = new BN(0);
const oneInBN = new BN(1);
const twoInBN = new BN(2);
const waitTimeInContract = new BN(process.env.WAIT_TIME_IN_CONTRACT);
const waitTimeInTest = process.env.WAIT_TIME_IN_TEST;

function wait(seconds) {
  return new Promise((resolve, reject) => setTimeout(resolve, seconds*1000));
}

contract('bountydAppv1', (accounts) => {

  let bdAv1Instance;
  let _bountyIDReceipt, _bountyID;
  let _solutionIDReceiptOne, _solutionIDOne, _solutionIDReceiptTwo, _solutionIDTwo, _solutionIDReceiptThree, _solutionIDThree;
  let _disputeIndexZero = zeroInBN, _disputeIndexOne = oneInBN;
  let owner, alice, bob, carol, resolverOne, resolverTwo, resolverThree;

  before("Preparing Accounts and Initial Checks", async function() {
    assert.isAtLeast(accounts.length, 7, "Atleast three accounts required");

    // Setup 7 accounts.
    [owner, alice, bob, carol, resolverOne, resolverTwo, resolverThree] = accounts;

    //Checking if all accounts have atleast 1 ETH or more for test
    assert.isTrue((new BN(await web3.eth.getBalance(owner))).gt(oneEtherInWei), "Owner Account has less than 1 ETH");
    assert.isTrue((new BN(await web3.eth.getBalance(alice))).gt(oneEtherInWei), "Alice Account has less than 1 ETH");
    assert.isTrue((new BN(await web3.eth.getBalance(bob))).gt(oneEtherInWei), "Bob Account has less than 1 ETH");
    assert.isTrue((new BN(await web3.eth.getBalance(carol))).gt(oneEtherInWei), "Carol Account has less than 1 ETH");
    assert.isTrue((new BN(await web3.eth.getBalance(resolverOne))).gt(oneEtherInWei), "Resolver One Account has less than 1 ETH");
    assert.isTrue((new BN(await web3.eth.getBalance(resolverTwo))).gt(oneEtherInWei), "Resolver Two Account has less than 1 ETH");
    assert.isTrue((new BN(await web3.eth.getBalance(resolverThree))).gt(oneEtherInWei), "Resolver Three Account has less than 1 ETH");

  });

  beforeEach("Creating New Instance", async function() {
    bdAv1Instance = await bdAv1.new(true, { from: owner});
    _bountyIDReceipt = await bdAv1Instance.createBounty(amount, deadline, description, {from: alice, value: amount});
    _bountyID = _bountyIDReceipt.receipt.logs[1].args.bountyID;
    _solutionIDReceiptOne = await bdAv1Instance.addSolution(_bountyID, zeroInBN, solution, {from: bob});
    _solutionIDOne = _solutionIDReceiptOne.receipt.logs[0].args.solutionID;
    _solutionIDReceiptTwo = await bdAv1Instance.addSolution(_bountyID, _solutionIDOne, solution, {from: bob});
    _solutionIDTwo = _solutionIDReceiptTwo.receipt.logs[0].args.solutionID;
    _solutionIDReceiptThree = await bdAv1Instance.addSolution(_bountyID, zeroInBN, solution, {from: carol});
    _solutionIDThree = _solutionIDReceiptThree.receipt.logs[0].args.solutionID;
    await bdAv1Instance.rejectSolution(_solutionIDTwo, comment, {from: alice});
    await bdAv1Instance.raiseDispute(_solutionIDTwo, {from: bob});
    await bdAv1Instance.addResolver(resolverOne, {from: owner});
    await bdAv1Instance.addResolver(resolverTwo, {from: owner});
    await bdAv1Instance.addResolver(resolverThree, {from: owner});
  });

  describe("Function: solveDispute", function() {

    describe("Basic Working", function() {

      it('Should solve a dispute for a solution submitted to a bounty correctly in favor', async () => {
        let beforeFunctionCallValue = new BN(await bdAv1Instance.balances(bob));
        await bdAv1Instance.solveDispute(_disputeIndexZero, oneInBN, {from: resolverOne});
        await bdAv1Instance.solveDispute(_disputeIndexZero, oneInBN, {from: resolverTwo});
        let afterFunctionCallValue = new BN(await bdAv1Instance.balances(bob));

        let _bountyDetails = await bdAv1Instance.bounties(_bountyID);
        let _acceptedSolutionID = _bountyDetails.acceptedSolutionID;
        let _status = _bountyDetails.status;

        let _solutionDetails = await bdAv1Instance.solutions(_solutionIDTwo);
        let _acceptanceStatus = _solutionDetails.acceptanceStatus;
        let _disputeStatus = _solutionDetails.disputeStatus;
  
        assert.strictEqual(beforeFunctionCallValue.toString(10), afterFunctionCallValue.sub(amount).toString(10), "Balance not updated correctly");
        assert.strictEqual(_acceptedSolutionID.toString(10), _solutionIDTwo.toString(10), "Acceptance Solution don't match");
        assert.strictEqual(_status.toString(10), twoInBN.toString(10), "Bounty Status don't match");
        assert.strictEqual(_acceptanceStatus.toString(10), oneInBN.toString(10), "Acceptance Status don't match");
        assert.strictEqual(_disputeStatus.toString(10), twoInBN.toString(10), "Dispute Status don't match");
      });

      it('Should solve a dispute for a solution submitted to a bounty correctly in against', async () => {
        let beforeFunctionCallValue = new BN(await bdAv1Instance.balances(bob));
        await bdAv1Instance.solveDispute(_disputeIndexZero, zeroInBN, {from: resolverOne});
        await bdAv1Instance.solveDispute(_disputeIndexZero, zeroInBN, {from: resolverTwo});
        await bdAv1Instance.solveDispute(_disputeIndexZero, oneInBN, {from: resolverThree});
        let afterFunctionCallValue = new BN(await bdAv1Instance.balances(bob));

        let _bountyDetails = await bdAv1Instance.bounties(_bountyID);
        let _status = _bountyDetails.status;

        let _solutionDetails = await bdAv1Instance.solutions(_solutionIDTwo);
        let _disputeStatus = _solutionDetails.disputeStatus;
  
        assert.strictEqual(beforeFunctionCallValue.toString(10), afterFunctionCallValue.toString(10), "Balance don't match");
        assert.strictEqual(_status.toString(10), zeroInBN.toString(10), "Bounty Status don't match");
        assert.strictEqual(_disputeStatus.toString(10), twoInBN.toString(10), "Dispute Status don't match");
      });

    });

    describe("Input Cases", function() {
    
      it('Without Dispute Index', async () => {
        await truffleAssert.fails(
          bdAv1Instance.solveDispute(oneInBN, {from: resolverOne}),
          null,
          ''
        );
      });

      it('Without Vote', async () => {
        await truffleAssert.fails(
          bdAv1Instance.solveDispute(_disputeIndexZero, {from: resolverOne}),
          null,
          ''
        );
      });

      it('Without any parameter', async () => {
        await truffleAssert.fails(
          bdAv1Instance.solveDispute({from: resolverOne}),
          null,
          ''
        );
      });

    });

    describe("Edge Cases", function() {

      it('solveDispute function can be called by Valid Resolvers only', async () => {
        await truffleAssert.fails(
          bdAv1Instance.solveDispute(_disputeIndexZero, zeroInBN, {from: bob}),
          null,
          'Only a Valid resolver can call this function'
        );
      });

      it('Resolver could only vote for dispute once', async () => {
        await bdAv1Instance.solveDispute(_disputeIndexZero, zeroInBN, {from: resolverOne});
        await truffleAssert.fails(
          bdAv1Instance.solveDispute(_disputeIndexZero, zeroInBN, {from: resolverOne}),
          null,
          'Already Signed'
        );
      });

      it('Could only vote either yes or no', async () => {
        await truffleAssert.fails(
          bdAv1Instance.solveDispute(_disputeIndexZero, twoInBN, {from: resolverOne}),
          null,
          'Either rejected or acccepted'
        );
      });

      it('Once majority is voted in favor, no need to vote again by remaining Resolvers', async () => {
        await bdAv1Instance.solveDispute(_disputeIndexZero, oneInBN, {from: resolverOne});
        await bdAv1Instance.solveDispute(_disputeIndexZero, oneInBN, {from: resolverTwo});
        await truffleAssert.fails(
          bdAv1Instance.solveDispute(_disputeIndexZero, zeroInBN, {from: resolverThree}),
          null,
          'Dispute solved already'
        );
      });

    });

    describe("Event Cases", function() {

      it("Should correctly emit the proper event: BountyClosedWithWinner", async () => {

        await bdAv1Instance.solveDispute(_disputeIndexZero, oneInBN, {from: resolverOne});
        let _disputeResolvedReceipt = await bdAv1Instance.solveDispute(_disputeIndexZero, oneInBN, {from: resolverTwo});

        assert.strictEqual(_disputeResolvedReceipt.logs.length, 2);
        const log = _disputeResolvedReceipt.logs[0];
    
        assert.strictEqual(log.event, "BountyClosedWithWinner");
        assert.strictEqual(log.args.bountyID.toString(10), _bountyID.toString(10));
        assert.strictEqual(log.args.bountyCloser, resolverTwo);
        assert.strictEqual(log.args.bountyWinner, bob);
      });

      it("Should correctly emit the proper event: DisputeSolved", async () => {

        await bdAv1Instance.solveDispute(_disputeIndexZero, oneInBN, {from: resolverOne});
        let _disputeResolvedReceipt = await bdAv1Instance.solveDispute(_disputeIndexZero, oneInBN, {from: resolverTwo});

        assert.strictEqual(_disputeResolvedReceipt.logs.length, 2);
        const log = _disputeResolvedReceipt.logs[1];
    
        assert.strictEqual(log.event, "DisputeSolved");
        assert.strictEqual(log.args.bountyID.toString(10), _bountyID.toString(10));
        assert.strictEqual(log.args.solutionID.toString(10), _solutionIDTwo.toString(10));
      });

      it("Should correctly emit the proper event: DisputeSolved", async () => {

        await bdAv1Instance.solveDispute(_disputeIndexZero, zeroInBN, {from: resolverOne});
        await bdAv1Instance.solveDispute(_disputeIndexZero, zeroInBN, {from: resolverTwo});
        let _disputeResolvedReceipt = await bdAv1Instance.solveDispute(_disputeIndexZero, zeroInBN, {from: resolverThree});

        assert.strictEqual(_disputeResolvedReceipt.logs.length, 1);
        const log = _disputeResolvedReceipt.logs[0];
    
        assert.strictEqual(log.event, "DisputeSolved");
        assert.strictEqual(log.args.bountyID.toString(10), _bountyID.toString(10));
        assert.strictEqual(log.args.solutionID.toString(10), _solutionIDTwo.toString(10));
      });

    });

  });

});