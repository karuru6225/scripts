#動作確認したのは以下のディスクでインストールし、wgetのみインストールした状態で実行
#CentOS-6.4-x86_64-netinstall.iso
#debian-6.0.6-amd64-netinst.iso

set -ex

if [ -f /etc/redhat-release ]; then
	UNAME=`cat /etc/redhat-release`
	if [[ ${OS} =~ .*CentOS\ release\ 6.* ]];then
	OS="centos"
	VER="6"
	elif [[ ${OS} =~ .*CentOS\ release\ 5.* ]];then
	OS="centos"
	VER="5"
	fi
elif [ -f /etc/debian_version ]; then
	OS="debian"
	VER=`cat /etc/debian_version`
fi

#x86_64決め打ちなので注意
if [ ${OS} == "centos" -a ${VER} == "6" ];then
	wget http://pkgs.repoforge.org/rpmforge-release/rpmforge-release-0.5.3-1.el6.rf.x86_64.rpm
	rpm -ivh rpmforge-release-0.5.3-1.el6.rf.x86_64.rpm
	rm -f rpmforge-release-*
	sed -e "/gpgkey/i priority=1" /etc/yum.repos.d/CentOS-Base.repo
elif [ ${OS} == "centos" -a ${VER} == "5" ];then
	wget http://pkgs.repoforge.org/rpmforge-release/rpmforge-release-0.5.3-1.el5.rf.x86_64.rpm
	rpm -ivh rpmforge-release-0.5.3-1.el5.rf.x86_64.rpm
	rm -f rpmforge-release-*
	sed -e "/gpgkey/i priority=1" /etc/yum.repos.d/CentOS-Base.repo
fi

if [ "${OS}" == "centos" ]; then
	yum -y install vim git yum-plugin-priorities man gcc gcc-c++ automake autoconf make openssl-devel.x86_64
	yum -y install tmux
elif [ "${OS}" == "debian" ]; then
	apt-get -y install git vim tmux build-essential libssl-dev
fi

cd /usr/local/
rm -rf rbenv
git clone git://github.com/sstephenson/rbenv.git rbenv
cat >> /etc/profile <<EOT
export RBENV_ROOT=/usr/local/rbenv
export PATH="\$RBENV_ROOT/bin:\$PATH"
eval "\$(rbenv init -)"
EOT
export RBENV_ROOT=/usr/local/rbenv
export PATH="$RBENV_ROOT/bin:$PATH"
eval "$(rbenv init -)"
if [ "`grep rbadmin /etc/group`" == "" ]; then
	/usr/sbin/groupadd rbadmin
fi
chgrp -R rbadmin rbenv
chmod -R g+rwxXs rbenv

mkdir /usr/local/rbenv/plugins
cd /usr/local/rbenv/plugins
git clone git://github.com/sstephenson/ruby-build.git
chgrp -R rbadmin ruby-build
chmod -R g+rwxs ruby-build

rbenv install 1.9.3-p392
rbenv global 1.9.3-p392
gem install bundler chef --no-rdoc --no-ri

cat > ~/.tmux.conf <<EOT
setw -g window-status-current-fg green
setw -g window-status-current-bg black
setw -g window-status-current-attr bold

set -g pane-active-border-fg black
set -g pane-active-border-bg cyan

bind    k select-pane -U
bind    j select-pane -D
bind    h select-pane -L
bind    l select-pane -R
EOT

cat >> ~/.bashrc <<EOT
#ヒストリー共有の設定
function share_history {
    history -a
    history -c
    history -r
}
PROMPT_COMMAND='share_history'
shopt -u histappend
export HISTSIZE=9999

#端末ロックをしない設定
stty stop undef

export EDITOR='vim'

export RBENV_ROOT=/usr/local/rbenv
export PATH="\$RBENV_ROOT/bin:\$PATH"
eval "\$(rbenv init -)"

alias ta='tmux has-session && tmux attach  || tmux ; exit'
EOT

cat > ~/.vimrc <<EOT
" vim: set ts=4 sw=4 sts=0:
"-----------------------------------------------------------------------------
" 文字コード関連
"
if &encoding !=# 'utf-8'
	set encoding=japan
	set fileencoding=japan
endif
if has('iconv')
	let s:enc_euc = 'euc-jp'
	let s:enc_jis = 'iso-2022-jp'
	" iconvがeucJP-msに対応しているかをチェック
	if iconv("\x87\x64\x87\x6a", 'cp932', 'eucjp-ms') ==# "\xad\xc5\xad\xcb"
		let s:enc_euc = 'eucjp-ms'
		let s:enc_jis = 'iso-2022-jp-3'
	" iconvがJISX0213に対応しているかをチェック
	elseif iconv("\x87\x64\x87\x6a", 'cp932', 'euc-jisx0213') ==# "\xad\xc5\xad\xcb"
		let s:enc_euc = 'euc-jisx0213'
		let s:enc_jis = 'iso-2022-jp-3'
	endif
	" fileencodingsを構築
	if &encoding ==# 'utf-8'
		let s:fileencodings_default = &fileencodings
		let &fileencodings = s:enc_jis .','. s:enc_euc .',cp932'
		let &fileencodings = &fileencodings .','. s:fileencodings_default
		unlet s:fileencodings_default
	else
		let &fileencodings = &fileencodings .','. s:enc_jis
		set fileencodings+=utf-8,ucs-2le,ucs-2
		if &encoding =~# '^\(euc-jp\|euc-jisx0213\|eucjp-ms\)$'
			set fileencodings+=cp932
			set fileencodings-=euc-jp
			set fileencodings-=euc-jisx0213
			set fileencodings-=eucjp-ms
			let &encoding = s:enc_euc
			let &fileencoding = s:enc_euc
		else
			let &fileencodings = &fileencodings .','. s:enc_euc
		endif
	endif
	" 定数を処分
	unlet s:enc_euc
	unlet s:enc_jis
endif
" 日本語を含まない場合は fileencoding に encoding を使うようにする
if has('autocmd')
	function! AU_ReCheck_FENC()
		if &fileencoding =~# 'iso-2022-jp' && search("[^\x01-\x7e]", 'n') == 0
			let &fileencoding=&encoding
		endif
	endfunction
	autocmd BufReadPost * call AU_ReCheck_FENC()
endif
" 改行コードの自動認識
set fileformats=unix,dos,mac
" □とか○の文字があってもカーソル位置がずれないようにする
if exists('&ambiwidth')
	set ambiwidth=double
endif

"-----------------------------------------------------------------------------
" 編集関連
"
"オートインデントする
set autoindent
"バイナリ編集(xxd)モード（vim -b での起動、もしくは *.bin で発動します）
augroup BinaryXXD
	autocmd!
	autocmd BufReadPre  *.bin let &binary =1
	autocmd BufReadPost * if &binary | silent %!xxd -g 1
	autocmd BufReadPost * set ft=xxd | endif
	autocmd BufWritePre * if &binary | %!xxd -r | endif
	autocmd BufWritePost * if &binary | silent %!xxd -g 1
	autocmd BufWritePost * set nomod | endif
augroup END

"-----------------------------------------------------------------------------
" 検索関連
"
"検索文字列が小文字の場合は大文字小文字を区別なく検索する
set ignorecase
"検索文字列に大文字が含まれている場合は区別して検索する
set smartcase
"検索時に最後まで行ったら最初に戻る
set wrapscan
"検索文字列入力時に順次対象文字列にヒットさせない
set noincsearch

"-----------------------------------------------------------------------------
" 装飾関連
"
"シンタックスハイライトを有効にする
if has("syntax")
	syntax on
	colorscheme elflord
endif
"行番号を表示しない
"set nonumber
set number
"タブの左側にカーソル表示
set listchars=tab:-\ 
set list
"タブ幅を設定する
set tabstop=4
set shiftwidth=4
"入力中のコマンドをステータスに表示する
set showcmd
"括弧入力時の対応する括弧を表示
set showmatch
"検索結果文字列のハイライトを有効にする
set hlsearch
"ステータスラインを常に表示
set laststatus=2
"ステータスラインに文字コードと改行文字を表示する
set statusline=%<%f\ %m%r%h%w%{'['.(&fenc!=''?&fenc:&enc).']['.&ff.']'}%=%l,%c%V%8P


"-----------------------------------------------------------------------------
" マップ定義
"
"バッファ移動用キーマップ
" F2: 前のバッファ
" F3: 次のバッファ
" F4: バッファ削除
"map <F2> <ESC>:bp<CR>
"map <F3> <ESC>:bn<CR>
"map <F4> <ESC>:bw<CR>
"表示行単位で行移動する
"nnoremap j gj
"nnoremap k gk
"フレームサイズを怠惰に変更する
"map <kPlus> <C-W>+
"map <kMinus> <C-W>-
EOT
