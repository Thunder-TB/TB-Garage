const app = document.getElementById('app');
const vehicleList = document.getElementById('vehicle-list');
const searchInput = document.getElementById('search');
const totalCount = document.getElementById('total-count');
const transferModal = document.getElementById('transfer-modal');
const impoundModal = document.getElementById('impound-modal');
const keyFob = document.getElementById('key-fob');
const textUi = document.getElementById('custom-textui');

let allVehicles = [];
let availableGarages = [];
let returnPrice = 500;
let isPaidReturn = true;
let transferConfig = {};
let currentGarageType = 'public';
let isPlayerPolice = false;

let currentTransferPlate = null;
let activeTransferTab = 'player';
let currentImpoundPlate = null;
let selectedImpoundMinutes = 0;
let renamePlate = null;

const postData = (endpoint, data = {}) => {
    fetch(`https://${GetParentResourceName()}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).catch(err => console.error(`NUI Error at ${endpoint}:`, err));
};

window.addEventListener('message', function(event) {
    const data = event.data;

    switch (data.action) {
        case 'open':
            handleOpenGarage(data);
            break;
        case 'returnSuccessful':
            closeAllUI();
            break;
        case 'toggleFob':
            toggleKeyFob();
            break;
        case 'showTextUI':
            document.getElementById('textui-key').innerText = data.key;
            document.getElementById('textui-label').innerText = data.label;
            textUi.style.display = 'block';
            break;
        case 'hideTextUI':
            textUi.style.display = 'none';
            break;
        case 'openImpoundForm':
            handleOpenImpoundForm(data);
            break;
    }
});

document.addEventListener('keyup', function(data) {
    if (data.which === 27 || data.key === "Escape") {
        if (isVisible(impoundModal)) {
            closeImpoundModal();
        } else if (isVisible(transferModal)) {
            closeTransferModal();
        } else if (isVisible(keyFob)) {
            toggleKeyFob(false);
        } else if (isVisible(app)) {
            closeAllUI();
        }
    }
});

searchInput.addEventListener('input', (e) => {
    const query = e.target.value.toLowerCase();
    const filtered = allVehicles.filter(v => 
        v.label.toLowerCase().includes(query) || 
        v.plate.toLowerCase().includes(query)
    );
    renderVehicles(filtered);
});

const isVisible = (elem) => elem && elem.style.display !== 'none' && elem.style.display !== '';

function handleOpenGarage(data) {
    allVehicles = data.vehicles || [];
    availableGarages = data.garages || [];
    currentGarageType = data.garageType || 'public';
    isPlayerPolice = data.isPolice || false;

    if (data.transferConfig) transferConfig = data.transferConfig;
    if (data.returnPrice !== undefined) returnPrice = data.returnPrice;
    if (data.chargeFee !== undefined) isPaidReturn = data.chargeFee;

    populateGarageSelect();

    app.style.display = 'block';
    renderVehicles(allVehicles);
}

function renderVehicles(vehicles) {
    vehicleList.innerHTML = '';
    totalCount.innerText = vehicles.length;
    const now = Math.floor(Date.now() / 1000); 
    

    if (vehicles.length === 0) {
        vehicleList.innerHTML = `
            <div class="no-vehicles-container">
                <i class="fa-solid fa-car-side"></i>
                <p>YOU DON'T HAVE ANY VEHICLES</p>
                <span>Check another garage or buy a new car!</span>
            </div>
        `;
        return;
    }

    vehicles.forEach((veh, index) => {
        const hasNickname = (veh.nickname && veh.nickname !== "" && veh.nickname !== "NULL");
        const mainTitle = hasNickname ? veh.nickname : veh.label;
        const subTitle = hasNickname ? veh.label : "";

        const item = document.createElement('div');
        item.classList.add('vehicle-item');
        item.id = `veh-${index}`;

        const fuel = Math.round(veh.fuel || 0);
        const engine = Math.round(((veh.engine || 1000) / 1000) * 100);

        let mainButton = '';
        let reasonHtml = '';

        if (currentGarageType === 'impound') {
            const fineFee = veh.fee || 0;

            if (isPlayerPolice) {
                mainButton = `
                    <button class="btn btn-spawn" style="background: #0088cc; margin-bottom: 5px;" onclick="retrieveImpound('${veh.plate}')">FORCE RELEASE</button>
                    <button class="btn btn-spawn" style="background: #2ecc71;" onclick="sendToGarage('${veh.plate}', 0)">SEND TO GARAGE (FREE)</button>
                `;
            } else {
                if (veh.releaseDate > now) {
                    const minsLeft = Math.ceil((veh.releaseDate - now) / 60);
                    mainButton = `<button class="btn btn-spawn btn-disabled"><i class="fa-solid fa-clock"></i> ${minsLeft} MINS</button>`;
                } else {
                    mainButton = `
                        <button class="btn btn-spawn btn-return" style="margin-bottom: 5px;" onclick="retrieveImpound('${veh.plate}')">RELEASE ($${fineFee})</button>
                        <button class="btn btn-spawn" style="background: #27ae60;" onclick="sendToGarage('${veh.plate}', ${fineFee})">SEND TO GARAGE ($${fineFee})</button>
                    `;
                }
            }
        } else if (veh.state === 'stored') {
            mainButton = `<button class="btn btn-spawn" onclick="spawnCar('${veh.plate}')">TAKE OUT</button>`;

        } else if (veh.state === 'out') {
            mainButton = `<button class="btn btn-spawn btn-disabled">ACTIVE</button>`;

        } else if (veh.state === 'impounded') {
            const btnText = isPaidReturn ? `RETURN ($${returnPrice})` : `RETURN`;
            mainButton = `<button class="btn btn-spawn btn-return" onclick="returnCar('${veh.plate}')">${btnText}</button>`;
        }

        let transferBtn = '';
        if (currentGarageType !== 'impound' && veh.impound != 1) {
            transferBtn = `<button class="btn btn-spawn btn-transfer" onclick="openTransferModal('${veh.plate}', '${veh.label}')">TRANSFER</button>`;
        }

        item.innerHTML = `
           <div class="vehicle-header" onclick="toggleVehicle(${index})">
                <div style="display: flex; flex-direction: column; flex: 1;">
                    <span style="font-size: 15px; font-weight: 700; color: #fff;">${mainTitle.toUpperCase()}</span>
                </div>
                <span class="plate-box">${veh.plate}</span>
                <i class="fa-solid fa-pen-to-square edit-name-icon" 
                   onclick="openRenameModal(event, '${veh.plate}')" 
                   style="margin-left: 15px; font-size: 13px; color: #444; cursor: pointer;"></i>
            </div>
            <div class="vehicle-details">
                <div class="details-inner-wrapper">
                    <div class="details-grid">
                        <div class="actions" style="justify-content: center;">
                            ${mainButton}
                            ${transferBtn}
                        </div>
                        <div class="stats">
                             ${reasonHtml}
                             <div class="stat-row">
                                <div class="stat-header"><span>Fuel</span><span>${fuel}%</span></div>
                                <div class="progress-bg"><div class="progress-fill fuel-bar" style="width: ${fuel}%"></div></div>
                            </div>
                            <div class="stat-row">
                                <div class="stat-header"><span>Engine</span><span>${engine}%</span></div>
                                <div class="progress-bg"><div class="progress-fill engine-bar" style="width: ${engine}%"></div></div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        `;
        vehicleList.appendChild(item);
    });
}

function toggleVehicle(index) {
    const selected = document.getElementById(`veh-${index}`);
    const isAlreadyOpen = selected.classList.contains('active');
    
    document.querySelectorAll('.vehicle-item').forEach(el => el.classList.remove('active'));

    if (!isAlreadyOpen) selected.classList.add('active');
}

function spawnCar(plate) {
    postData('spawnVehicle', { plate: plate });
    closeAllUI();
}

function returnCar(plate) {
    postData('payReturn', { plate: plate });
    closeAllUI();
}

function retrieveImpound(plate) {
    postData('retrieveImpound', { plate: plate });
    closeAllUI();
}

function populateGarageSelect() {
    const select = document.getElementById('transfer-target-garage');
    if (!select) return;
    
    select.innerHTML = '';
    availableGarages.forEach(garage => {
        const opt = document.createElement('option');
        opt.value = garage.name;
        opt.innerText = garage.name.toUpperCase();
        select.appendChild(opt);
    });
}

function openTransferModal(plate, label) {
    currentTransferPlate = plate;
    document.getElementById('modal-plate-display').innerText = `VEHICLE: ${label} [${plate}]`;
    switchTab('player');
    transferModal.style.display = 'flex';
}

function closeTransferModal() {
    transferModal.style.display = 'none';
    document.getElementById('transfer-target-id').value = '';
}

function switchTab(tab) {
    activeTransferTab = tab;

    document.getElementById('tab-player').classList.toggle('active', tab === 'player');
    document.getElementById('tab-garage').classList.toggle('active', tab === 'garage');
    
    document.getElementById('section-player').style.display = (tab === 'player') ? 'block' : 'none';
    document.getElementById('section-garage').style.display = (tab === 'garage') ? 'block' : 'none';

    const confirmBtn = document.querySelector('.btn-confirm');
    let fee = 0;

    if (tab === 'garage') {
        fee = (transferConfig.GarageFeeEnabled) ? transferConfig.GarageFee : 0;
    } else {
        fee = (transferConfig.PlayerFeeEnabled) ? transferConfig.PlayerFee : 0;
    }

    confirmBtn.innerText = (fee > 0) ? `CONFIRM ($${fee})` : "CONFIRM (FREE)";
}

function submitTransfer() {
    if (!currentTransferPlate) return;

    let payload = {
        plate: currentTransferPlate,
        type: activeTransferTab,
        target: ''
    };

    if (activeTransferTab === 'player') {
        const targetId = document.getElementById('transfer-target-id').value;
        if (!targetId) return; 
        payload.target = targetId;
    } else {
        payload.target = document.getElementById('transfer-target-garage').value;
    }

    postData('transferVehicle', payload);
    closeTransferModal();
    closeAllUI();
}

function handleOpenImpoundForm(data) {
    currentImpoundPlate = data.plate;
    document.getElementById('impound-plate-display').innerText = `IMPOUNDING: ${data.plate}`;
    impoundModal.style.display = 'flex';
    app.style.display = 'none';
}

function closeImpoundModal() {
    impoundModal.style.display = 'none';
    
    document.getElementById('imp-reason').value = '';
    document.getElementById('imp-time-custom').value = '';
    document.getElementById('imp-fine').value = '';
    clearTimeButtons();
    
    postData('close');
}

function setImpoundTime(hours, btnElement) {
    document.querySelectorAll('.time-btn').forEach(b => b.classList.remove('active'));
    if (btnElement) btnElement.classList.add('active');

    document.getElementById('imp-time-custom').value = '';
    selectedImpoundMinutes = hours * 60;
}

function clearTimeButtons() {
    document.querySelectorAll('.time-btn').forEach(b => b.classList.remove('active'));
    selectedImpoundMinutes = 0;
}

function submitImpound() {
    const reason = document.getElementById('imp-reason').value;
    const fine = document.getElementById('imp-fine').value;
    const customHours = document.getElementById('imp-time-custom').value;

    let finalMinutes = selectedImpoundMinutes;

    if (customHours && customHours !== '') {
        finalMinutes = parseInt(customHours) * 60;
    }

    if (!reason || !fine) return;

    postData('submitImpound', {
        plate: currentImpoundPlate,
        reason: reason,
        time: parseInt(finalMinutes),
        fine: parseInt(fine)
    });

    closeImpoundModal();
}

function toggleKeyFob(forceState) {
    const isCurrentlyVisible = isVisible(keyFob);
    
    if (forceState === false) {
        keyFob.style.display = 'none';
        postData('closeFob');
        return;
    }

    if (!isCurrentlyVisible) {
        keyFob.style.display = 'block';
    } else {
        keyFob.style.display = 'none';
        postData('closeFob');
    }
}

function sendAction(actionType) {
    postData('fobAction', { action: actionType });
}

function closeAllUI() {
    app.style.display = 'none';
    if (transferModal) transferModal.style.display = 'none';
    postData('close');
}

function sendToGarage(plate, fee) {
    postData('sendToGarage', { plate: plate, fee: fee });
    closeAllUI();
}


function openRenameModal(event, plate) {
    event.stopPropagation();
    renamePlate = plate;
    document.getElementById('rename-modal').style.display = 'flex';
    document.getElementById('new-nickname').focus();
}

function closeRenameModal() {
    document.getElementById('rename-modal').style.display = 'none';
    document.getElementById('new-nickname').value = '';
}

function submitRename() {
    const name = document.getElementById('new-nickname').value;
    if (!renamePlate) return;
    
    postData('renameVehicle', { plate: renamePlate, nickname: name });
    closeRenameModal();
    closeAllUI();
}