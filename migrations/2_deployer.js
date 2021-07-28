const GroupDeployer = artifacts.require("GroupDeployer");

module.exports = function (deployer, network) {
    let host, cfa, superTokenFactory;

    if (network == 'ropsten')
    {
        host = '0xF2B4E81ba39F5215Db2e05B2F66f482BB8e87FD2'
        cfa = '0xaD2F1f7cd663f6a15742675f975CcBD42bb23a88'
        superTokenFactory = '0x6FA165d10b907592779301C23C8Ac9d1F79ca930'
    }
    else if (network == 'mumbai')
    {
        host = '0xEB796bdb90fFA0f28255275e16936D25d3418603'
        cfa = '0x49e565Ed1bdc17F3d220f72DF0857C26FA83F873'
        superTokenFactory = '0x200657E2f123761662567A1744f9ACAe50dF47E6'
    } else throw("GroupDeployer: Invalid network selected")
    
  deployer.deploy(GroupDeployer, host, cfa, superTokenFactory);
};
