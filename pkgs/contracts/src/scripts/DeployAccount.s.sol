import {Script} from "forge-std/Script.sol";
import {HappyAccountFactoryBase} from "boop/happychain/factories/HappyAccountFactoryBase.sol";
import {console} from "forge-std/console.sol";

contract DeployAccount is Script {
    bytes32 private SALT = bytes32(0);

    function run() external {
        HappyAccountFactoryBase accountFactory = HappyAccountFactoryBase(vm.envAddress("ACCOUNT_FACTORY"));
        (address ctrlAddr, uint256 ctrlKey) = makeAddrAndKey("ctrl");
        address account = accountFactory.createAccount(SALT, ctrlAddr);
        console.log("account address", account);
        console.log("controlling address", ctrlAddr);
        console.log("controlling private key", ctrlKey);
    }
}